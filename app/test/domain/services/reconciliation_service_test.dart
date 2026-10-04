import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/domain/models/models.dart';
import 'package:bucket_app/domain/services/reconciliation_service.dart';
import 'package:bucket_app/core/networking/mock_sync_provider.dart';
import 'package:bucket_app/core/database/in_memory/in_memory_repositories.dart';

void main() {
  group('ReconciliationService Pipeline Tests', () {
    final now = DateTime(2026, 10, 1);

    late MockSyncProvider mockProvider;
    late InMemoryAccountRepository accountRepo;
    late InMemoryBucketRepository bucketRepo;
    late InMemoryLedgerRepository ledgerRepo;
    late InMemorySyncSessionRepository sessionRepo;
    late ReconciliationService service;

    setUp(() async {
      mockProvider = MockSyncProvider(
        initialBalancePaise: 3000000, // ₹30,000
        simulatedLatency: Duration.zero,
      );

      final initialAccount = Account(
        id: 'acc_1',
        accountNumberMask: 'XX4589',
        bankName: 'HDFC Bank',
        totalBalancePaise: 3000000, // ₹30,000
        lastSyncedAt: now,
        createdAt: now,
      );
      accountRepo = InMemoryAccountRepository(initialAccount);

      final ps5 = Bucket(
        id: 'ps5',
        name: 'PS5',
        icon: '🎮',
        targetAmountPaise: 5000000,
        currentAllocationPaise: 700000, // ₹7,000 (P1 WANT -> 1st to sacrifice)
        category: 'Gaming',
        type: BucketType.want,
        priority: 1,
        createdAt: now,
        updatedAt: now,
      );

      final rent = Bucket(
        id: 'rent',
        name: 'Rent',
        icon: '🏠',
        targetAmountPaise: 1000000,
        currentAllocationPaise: 1000000, // ₹10,000 (P5 NEED Protected)
        category: 'Housing',
        type: BucketType.need,
        priority: 5,
        isProtected: true,
        createdAt: now,
        updatedAt: now,
      );

      bucketRepo = InMemoryBucketRepository([ps5, rent]);
      // Total allocated: ₹17,000. Spendable: ₹30,000 - ₹17,000 = ₹13,000.

      ledgerRepo = InMemoryLedgerRepository();
      sessionRepo = InMemorySyncSessionRepository();

      service = ReconciliationService(
        syncProvider: mockProvider,
        accountRepository: accountRepo,
        bucketRepository: bucketRepo,
        ledgerRepository: ledgerRepo,
        syncSessionRepository: sessionRepo,
      );
    });

    test('sync with no balance change returns neutral outcome', () async {
      final outcome = await service.runSync();

      expect(outcome.classification, equals(SyncClassification.noChange));
      expect(outcome.differencePaise, equals(0));
      expect(outcome.affectedBuckets, isEmpty);
      expect(outcome.generatedLedgerEntries, isEmpty);
    });

    test('external spend detected in bank provider triggers waterfall deduction on PS5', () async {
      // Spend ₹15,000 outside app at Supermarket
      // Spendable was ₹13,000 -> absorbs ₹13,000 -> leaves ₹2,000 deficit.
      // PS5 (₹7,000) absorbs ₹2,000 -> new balance ₹5,000.
      mockProvider.simulateExternalSpend(amountPaise: 1500000, merchantName: 'Supermarket');

      final outcome = await service.runSync();

      expect(outcome.classification, equals(SyncClassification.externalSpend));
      expect(outcome.differencePaise, equals(-1500000));
      expect(outcome.affectedBuckets.length, equals(1));
      expect(outcome.affectedBuckets.first.originalBucket.id, equals('ps5'));
      expect(outcome.affectedBuckets.first.deductedAmountPaise, equals(200000)); // ₹2,000
      expect(outcome.affectedBuckets.first.updatedBucket.currentAllocationPaise, equals(500000)); // ₹5,000 left

      // Verify repository updates
      final updatedAccount = await accountRepo.getAccount();
      expect(updatedAccount?.totalBalancePaise, equals(1500000)); // ₹15,000

      final updatedPs5 = await bucketRepo.getBucketById('ps5');
      expect(updatedPs5?.currentAllocationPaise, equals(500000));

      final ledgerEntries = await ledgerRepo.getAllEntries();
      expect(ledgerEntries.length, equals(1));
      expect(ledgerEntries.first.transactionType, equals(TransactionType.externalSpendImpact));
      expect(ledgerEntries.first.amountDeltaPaise, equals(-200000));
    });

    test('incoming funds detected in bank provider credits spendable pool', () async {
      // Bank balance increases by ₹10,000 (salary/bonus)
      mockProvider.simulateIncomingMoney(amountPaise: 1000000, source: 'Bonus Credit');

      final outcome = await service.runSync();

      expect(outcome.classification, equals(SyncClassification.incomingFunds));
      expect(outcome.differencePaise, equals(1000000));
      expect(outcome.affectedBuckets, isEmpty); // Goals untouched

      final updatedAccount = await accountRepo.getAccount();
      expect(updatedAccount?.totalBalancePaise, equals(4000000)); // ₹40,000

      final entries = await ledgerRepo.getAllEntries();
      expect(entries.length, equals(1));
      expect(entries.first.transactionType, equals(TransactionType.incomeDetected));
      expect(entries.first.amountDeltaPaise, equals(1000000));
    });

    test('idempotency prevents duplicate ledger entries on rapid syncs', () async {
      // First sync
      final firstOutcome = await service.runSync();
      expect(firstOutcome.status, equals('COMPLETED'));

      final initialEntryCount = (await ledgerRepo.getAllEntries()).length;

      // Second sync with same provider state without force flag
      final secondOutcome = await service.runSync(force: false);
      expect(secondOutcome.isIdempotentDuplicate, isTrue);

      final afterEntryCount = (await ledgerRepo.getAllEntries()).length;
      expect(afterEntryCount, equals(initialEntryCount)); // Zero new entries written
    });

    test('offline network error is handled gracefully without corrupting state', () async {
      mockProvider.setOffline(true);

      final outcome = await service.runSync();

      expect(outcome.classification, equals(SyncClassification.offlineFailure));
      expect(outcome.status, equals('FAILED'));

      // Account balance remains untouched
      final account = await accountRepo.getAccount();
      expect(account?.totalBalancePaise, equals(3000000));
    });
  });
}
