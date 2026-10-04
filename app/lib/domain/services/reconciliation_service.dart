import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../engines/external_spend_engine.dart';
import '../engines/incoming_money_engine.dart';
import '../../core/networking/sync_provider.dart';

enum SyncClassification {
  noChange,
  externalSpend,
  incomingFunds,
  refund,
  offlineFailure,
}

/// Detailed outcome returned by ReconciliationService.runSync().
class SyncOutcome {
  final SyncClassification classification;
  final int previousBalancePaise;
  final int currentBalancePaise;
  final int differencePaise;
  final bool isIdempotentDuplicate;
  final List<BucketImpact> affectedBuckets;
  final List<Bucket> allUpdatedBuckets;
  final List<LedgerEntry> generatedLedgerEntries;
  final String sessionHash;
  final String status;
  final String message;
  final DateTime timestamp;

  const SyncOutcome({
    required this.classification,
    required this.previousBalancePaise,
    required this.currentBalancePaise,
    required this.differencePaise,
    this.isIdempotentDuplicate = false,
    this.affectedBuckets = const [],
    this.allUpdatedBuckets = const [],
    this.generatedLedgerEntries = const [],
    required this.sessionHash,
    required this.status,
    required this.message,
    required this.timestamp,
  });

  double get differenceRupees => differencePaise / 100.0;
  double get currentBalanceRupees => currentBalancePaise / 100.0;
}

/// Orchestrates real-time balance reconciliation against virtual goal buckets.
class ReconciliationService {
  static const _uuid = Uuid();

  final IBalanceSyncProvider syncProvider;
  final IAccountRepository accountRepository;
  final IBucketRepository bucketRepository;
  final ILedgerRepository ledgerRepository;
  final ISyncSessionRepository syncSessionRepository;

  const ReconciliationService({
    required this.syncProvider,
    required this.accountRepository,
    required this.bucketRepository,
    required this.ledgerRepository,
    required this.syncSessionRepository,
  });

  /// Generates a deterministic SHA-256 session hash for idempotency checking.
  static String computeSessionHash({
    required String accountId,
    required int balancePaise,
    required DateTime timestamp,
  }) {
    // Quantize timestamp to 10-second window to prevent rapid retry double-syncs
    final windowSeconds = (timestamp.millisecondsSinceEpoch ~/ 10000) * 10;
    final payload = '$accountId:$balancePaise:$windowSeconds';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Executes the complete sync and reconciliation pipeline.
  Future<SyncOutcome> runSync({bool force = false}) async {
    final now = DateTime.now();

    // 1. Fetch current account record
    final account = await accountRepository.getAccount();
    if (account == null) {
      throw StateError('Cannot run sync: No bank account has been initialized.');
    }

    // 2. Contact Sync Provider
    BalanceSyncResult syncResult;
    try {
      syncResult = await syncProvider.fetchCurrentBalanceAndTransactions(since: account.lastSyncedAt);
    } catch (e) {
      return SyncOutcome(
        classification: SyncClassification.offlineFailure,
        previousBalancePaise: account.totalBalancePaise,
        currentBalancePaise: account.totalBalancePaise,
        differencePaise: 0,
        sessionHash: 'failed_${now.millisecondsSinceEpoch}',
        status: 'FAILED',
        message: 'Sync offline: Unable to reach bank provider. Showing cached data.',
        timestamp: now,
      );
    }

    final newBalance = syncResult.currentBalancePaise;
    final prevBalance = account.totalBalancePaise;
    final diff = newBalance - prevBalance;

    // 3. Idempotency Check
    final sessionHash = computeSessionHash(
      accountId: account.id,
      balancePaise: newBalance,
      timestamp: syncResult.timestamp,
    );

    if (!force && await syncSessionRepository.isSessionProcessed(sessionHash)) {
      return SyncOutcome(
        classification: SyncClassification.noChange,
        previousBalancePaise: prevBalance,
        currentBalancePaise: newBalance,
        differencePaise: 0,
        isIdempotentDuplicate: true,
        sessionHash: sessionHash,
        status: 'COMPLETED',
        message: 'Account is already up to date (idempotent sync).',
        timestamp: now,
      );
    }

    // 4. Load Active Buckets
    final buckets = await bucketRepository.getAllBuckets();
    final activeBuckets = buckets.where((b) => !b.isCompleted).toList();
    final totalAllocated = activeBuckets.fold<int>(0, (sum, b) => sum + b.currentAllocationPaise);
    final spendableBalance = prevBalance - totalAllocated;

    // 5. Classify Difference & Run Engines
    SyncClassification classification;
    List<BucketImpact> affectedBuckets = [];
    List<Bucket> allUpdatedBuckets = List.from(buckets);
    List<LedgerEntry> generatedEntries = [];
    String message;

    if (diff == 0) {
      classification = SyncClassification.noChange;
      message = 'All balances up to date. No difference detected.';
    } else if (diff < 0) {
      classification = SyncClassification.externalSpend;
      final spendAmount = diff.abs();

      final waterfallResult = ExternalSpendEngine.executeWaterfall(
        spendAmountPaise: spendAmount,
        unallocatedBalancePaise: spendableBalance,
        activeBuckets: activeBuckets,
        timestamp: now,
      );

      affectedBuckets = waterfallResult.affectedBuckets;
      generatedEntries = waterfallResult.generatedLedgerEntries;

      // Update buckets in repository
      for (final updatedBucket in waterfallResult.allUpdatedBuckets) {
        await bucketRepository.updateBucket(updatedBucket);
      }
      allUpdatedBuckets = await bucketRepository.getAllBuckets();

      // Commit ledger entries
      if (generatedEntries.isNotEmpty) {
        await ledgerRepository.appendEntries(generatedEntries);
      }

      message = 'Detected external spending of -₹${spendAmount / 100}. '
          'Allocated accounting impact to ${affectedBuckets.length} goal(s).';
    } else {
      // Check if any transaction is a refund
      final hasRefund = syncResult.transactions.any((t) => t.type == ExternalTransactionType.refund);
      classification = hasRefund ? SyncClassification.refund : SyncClassification.incomingFunds;

      final incomeResult = IncomingMoneyEngine.processIncoming(
        incomingAmountPaise: diff,
        currentUnallocatedPaise: spendableBalance,
        note: hasRefund ? 'Refund credited to spendable pool' : 'Incoming money detected via sync',
        timestamp: now,
      );

      generatedEntries = [incomeResult.ledgerEntry];
      await ledgerRepository.appendEntry(incomeResult.ledgerEntry);

      message = 'Detected incoming funds of +₹${diff / 100} credited to spendable pool.';
    }

    // 6. Update Account Store
    await accountRepository.updateBalance(newBalance);
    await accountRepository.updateLastSynced(now);

    // 7. Save SyncSession Audit
    final sessionRecord = SyncSession(
      id: _uuid.v4(),
      sessionHash: sessionHash,
      previousBalancePaise: prevBalance,
      currentBalancePaise: newBalance,
      differencePaise: diff,
      classification: classification.name,
      impactSummaryJson: jsonEncode(affectedBuckets.map((a) => {
        'bucket_id': a.originalBucket.id,
        'name': a.originalBucket.name,
        'deducted_paise': a.deductedAmountPaise,
      }).toList()),
      status: 'COMPLETED',
      createdAt: now,
    );
    await syncSessionRepository.saveSession(sessionRecord);

    return SyncOutcome(
      classification: classification,
      previousBalancePaise: prevBalance,
      currentBalancePaise: newBalance,
      differencePaise: diff,
      affectedBuckets: affectedBuckets,
      allUpdatedBuckets: allUpdatedBuckets,
      generatedLedgerEntries: generatedEntries,
      sessionHash: sessionHash,
      status: 'COMPLETED',
      message: message,
      timestamp: now,
    );
  }
}
