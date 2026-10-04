import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/models.dart';
import '../../domain/engines/allocation_engine.dart';
import '../../domain/engines/external_spend_engine.dart';
import '../../domain/engines/incoming_money_engine.dart';

/// State of the wallet, accounts, buckets, and audit ledger.
class WalletState {
  final Account account;
  final List<Bucket> buckets;
  final List<LedgerEntry> recentLedger;
  final bool isLoading;
  final String? errorMessage;
  final String? lastSyncMessage;
  final WaterfallResult? lastWaterfallResult;

  const WalletState({
    required this.account,
    required this.buckets,
    required this.recentLedger,
    this.isLoading = false,
    this.errorMessage,
    this.lastSyncMessage,
    this.lastWaterfallResult,
  });

  int get totalBankBalancePaise => account.totalBalancePaise;
  int get totalAllocatedPaise => buckets.fold<int>(0, (sum, b) => sum + b.currentAllocationPaise);
  int get spendableBalancePaise => totalBankBalancePaise - totalAllocatedPaise;

  double get totalBankRupees => totalBankBalancePaise / 100.0;
  double get totalAllocatedRupees => totalAllocatedPaise / 100.0;
  double get spendableRupees => spendableBalancePaise / 100.0;

  bool get hasDeficit => spendableBalancePaise < 0;

  WalletState copyWith({
    Account? account,
    List<Bucket>? buckets,
    List<LedgerEntry>? recentLedger,
    bool? isLoading,
    String? errorMessage,
    String? lastSyncMessage,
    WaterfallResult? lastWaterfallResult,
    bool clearWaterfall = false,
  }) {
    return WalletState(
      account: account ?? this.account,
      buckets: buckets ?? this.buckets,
      recentLedger: recentLedger ?? this.recentLedger,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastSyncMessage: lastSyncMessage ?? this.lastSyncMessage,
      lastWaterfallResult: clearWaterfall ? null : (lastWaterfallResult ?? this.lastWaterfallResult),
    );
  }
}

/// Riverpod StateNotifier managing all local wallet operations and invariants.
class WalletNotifier extends StateNotifier<WalletState> {
  static const _uuid = Uuid();

  WalletNotifier() : super(_createInitialState());

  static WalletState _createInitialState() {
    final now = DateTime.now();

    final account = Account(
      id: 'acc_primary',
      accountNumberMask: 'XX4589',
      bankName: 'HDFC Bank',
      totalBalancePaise: 3000000, // ₹30,000
      lastSyncedAt: now.subtract(const Duration(minutes: 15)),
      createdAt: now.subtract(const Duration(days: 30)),
    );

    // Initial buckets matching product concept
    final buckets = [
      Bucket(
        id: 'b_rent',
        name: 'Rent',
        icon: '🏠',
        targetAmountPaise: 1000000, // ₹10,000
        currentAllocationPaise: 1000000, // ₹10,000
        deadline: DateTime(now.year, now.month + 1, 1),
        category: 'Housing',
        type: BucketType.need,
        priority: 5,
        isProtected: true, // Protected against auto-deduction
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
      Bucket(
        id: 'b_laptop',
        name: 'Laptop M4',
        icon: '💻',
        targetAmountPaise: 8000000, // ₹80,000
        currentAllocationPaise: 800000, // ₹8,000
        deadline: DateTime(now.year + 1, 12, 31),
        category: 'Tech',
        type: BucketType.want,
        priority: 4,
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now.subtract(const Duration(days: 8)),
      ),
      Bucket(
        id: 'b_shoes',
        name: 'Nike Sneakers',
        icon: '👟',
        targetAmountPaise: 1000000, // ₹10,000
        currentAllocationPaise: 500000, // ₹5,000
        deadline: DateTime(now.year, now.month + 2, 15),
        category: 'Shopping',
        type: BucketType.want,
        priority: 2,
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(days: 6)),
      ),
      Bucket(
        id: 'b_ps5',
        name: 'PS5 Pro',
        icon: '🎮',
        targetAmountPaise: 7000000, // ₹70,000
        currentAllocationPaise: 700000, // ₹7,000 (P1 WANT -> 1st to sacrifice)
        deadline: DateTime(now.year, now.month + 4, 30),
        category: 'Gaming',
        type: BucketType.want,
        priority: 1,
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
    ];

    // Seed initial ledger entries
    final recentLedger = [
      LedgerEntry(
        id: 'init_1',
        bucketId: 'b_rent',
        transactionType: TransactionType.initialAllocation,
        amountDeltaPaise: 1000000,
        balanceAfterPaise: 1000000,
        note: 'Initial allocation: Rent',
        timestamp: now.subtract(const Duration(days: 10)),
      ),
      LedgerEntry(
        id: 'init_2',
        bucketId: 'b_laptop',
        transactionType: TransactionType.initialAllocation,
        amountDeltaPaise: 800000,
        balanceAfterPaise: 800000,
        note: 'Initial allocation: Laptop',
        timestamp: now.subtract(const Duration(days: 8)),
      ),
      LedgerEntry(
        id: 'init_3',
        bucketId: 'b_shoes',
        transactionType: TransactionType.initialAllocation,
        amountDeltaPaise: 500000,
        balanceAfterPaise: 500000,
        note: 'Initial allocation: Nike Sneakers',
        timestamp: now.subtract(const Duration(days: 6)),
      ),
      LedgerEntry(
        id: 'init_4',
        bucketId: 'b_ps5',
        transactionType: TransactionType.initialAllocation,
        amountDeltaPaise: 700000,
        balanceAfterPaise: 700000,
        note: 'Initial allocation: PS5 Pro',
        timestamp: now.subtract(const Duration(days: 4)),
      ),
    ];

    return WalletState(
      account: account,
      buckets: buckets,
      recentLedger: recentLedger.reversed.toList(),
    );
  }

  /// Allocates spendable money to a goal bucket.
  void allocateToBucket(String bucketId, int amountPaise, {String? note}) {
    final bucket = state.buckets.firstWhere((b) => b.id == bucketId);
    final result = AllocationEngine.allocate(
      bucket: bucket,
      amountPaise: amountPaise,
      currentUnallocatedPaise: state.spendableBalancePaise,
      note: note,
    );

    final updatedBuckets = state.buckets.map((b) => b.id == bucketId ? result.updatedBucket : b).toList();
    final updatedLedger = [result.ledgerEntry, ...state.recentLedger];

    state = state.copyWith(
      buckets: updatedBuckets,
      recentLedger: updatedLedger,
      lastSyncMessage: 'Allocated ₹${amountPaise / 100} to ${bucket.name}',
    );
  }

  /// Deallocates money from a goal bucket back to the spendable pool.
  void deallocateFromBucket(String bucketId, int amountPaise, {String? note}) {
    final bucket = state.buckets.firstWhere((b) => b.id == bucketId);
    final result = AllocationEngine.deallocate(
      bucket: bucket,
      amountPaise: amountPaise,
      currentUnallocatedPaise: state.spendableBalancePaise,
      note: note,
    );

    final updatedBuckets = state.buckets.map((b) => b.id == bucketId ? result.updatedBucket : b).toList();
    final updatedLedger = [result.ledgerEntry, ...state.recentLedger];

    state = state.copyWith(
      buckets: updatedBuckets,
      recentLedger: updatedLedger,
      lastSyncMessage: 'Returned ₹${amountPaise / 100} from ${bucket.name} to spendable pool',
    );
  }

  /// Reallocates virtual funds between two buckets without real bank movement.
  void reallocateBetweenBuckets(String fromBucketId, String toBucketId, int amountPaise, {String? note}) {
    final fromBucket = state.buckets.firstWhere((b) => b.id == fromBucketId);
    final toBucket = state.buckets.firstWhere((b) => b.id == toBucketId);

    final result = AllocationEngine.reallocate(
      fromBucket: fromBucket,
      toBucket: toBucket,
      amountPaise: amountPaise,
      note: note,
    );

    final updatedBuckets = state.buckets.map((b) {
      if (b.id == fromBucketId) return result.updatedSourceBucket;
      if (b.id == toBucketId) return result.updatedTargetBucket;
      return b;
    }).toList();

    final updatedLedger = [
      result.targetLedgerEntry,
      result.sourceLedgerEntry,
      ...state.recentLedger,
    ];

    state = state.copyWith(
      buckets: updatedBuckets,
      recentLedger: updatedLedger,
      lastSyncMessage: 'Reallocated ₹${amountPaise / 100} from ${fromBucket.name} to ${toBucket.name}',
    );
  }

  /// Creates a new goal bucket.
  void createBucket(Bucket newBucket, {int initialAllocationPaise = 0}) {
    final now = DateTime.now();
    Bucket bucketToSave = newBucket;
    final List<LedgerEntry> entries = [];

    if (initialAllocationPaise > 0) {
      if (initialAllocationPaise > state.spendableBalancePaise) {
        throw StateError('Initial allocation exceeds spendable balance.');
      }
      bucketToSave = newBucket.copyWith(currentAllocationPaise: initialAllocationPaise);
      entries.add(LedgerEntry(
        id: _uuid.v4(),
        bucketId: newBucket.id,
        transactionType: TransactionType.initialAllocation,
        amountDeltaPaise: initialAllocationPaise,
        balanceAfterPaise: initialAllocationPaise,
        note: 'Initial allocation on creation',
        timestamp: now,
      ));
    }

    state = state.copyWith(
      buckets: [...state.buckets, bucketToSave],
      recentLedger: [...entries, ...state.recentLedger],
      lastSyncMessage: 'Created goal: ${newBucket.name}',
    );
  }

  /// Updates an existing goal bucket metadata.
  void updateBucket(Bucket updatedBucket) {
    state = state.copyWith(
      buckets: state.buckets.map((b) => b.id == updatedBucket.id ? updatedBucket : b).toList(),
      lastSyncMessage: 'Updated ${updatedBucket.name}',
    );
  }

  /// Deletes a goal bucket and refunds its allocated funds to spendable pool.
  void deleteBucket(String bucketId) {
    final bucket = state.buckets.firstWhere((b) => b.id == bucketId);
    final currentAlloc = bucket.currentAllocationPaise;
    final List<LedgerEntry> entries = [];

    if (currentAlloc > 0) {
      entries.add(LedgerEntry(
        id: _uuid.v4(),
        bucketId: bucket.id,
        transactionType: TransactionType.manualRemove,
        amountDeltaPaise: -currentAlloc,
        balanceAfterPaise: 0,
        note: 'Bucket deleted: refunded ₹${currentAlloc / 100} to spendable',
        timestamp: DateTime.now(),
      ));
    }

    state = state.copyWith(
      buckets: state.buckets.where((b) => b.id != bucketId).toList(),
      recentLedger: [...entries, ...state.recentLedger],
      lastSyncMessage: 'Deleted goal: ${bucket.name}',
    );
  }

  /// Simulates a bank balance change (Sync simulator).
  /// Detects difference and triggers either Waterfall deduction or Income detection.
  void simulateBalanceSync(int newBankBalancePaise) {
    final prevBalance = state.totalBankBalancePaise;
    final delta = newBankBalancePaise - prevBalance;
    final now = DateTime.now();

    if (delta == 0) {
      state = state.copyWith(
        account: state.account.copyWith(lastSyncedAt: now),
        lastSyncMessage: 'Balances up to date. No difference detected.',
        clearWaterfall: true,
      );
      return;
    }

    if (delta < 0) {
      // External Spending Detected!
      final spendAmount = delta.abs();
      final waterfallResult = ExternalSpendEngine.executeWaterfall(
        spendAmountPaise: spendAmount,
        unallocatedBalancePaise: state.spendableBalancePaise,
        activeBuckets: state.buckets,
        timestamp: now,
      );

      final updatedAccount = state.account.copyWith(
        totalBalancePaise: newBankBalancePaise,
        lastSyncedAt: now,
      );

      final updatedLedger = [
        ...waterfallResult.generatedLedgerEntries,
        ...state.recentLedger,
      ];

      state = state.copyWith(
        account: updatedAccount,
        buckets: waterfallResult.allUpdatedBuckets,
        recentLedger: updatedLedger,
        lastWaterfallResult: waterfallResult,
        lastSyncMessage: 'Sync detected external spending of -₹${spendAmount / 100}. Reallocated accounting impact.',
      );
    } else {
      // Incoming Money Detected!
      final incomeResult = IncomingMoneyEngine.processIncoming(
        incomingAmountPaise: delta,
        currentUnallocatedPaise: state.spendableBalancePaise,
        note: 'Incoming funds detected via balance sync',
        timestamp: now,
      );

      final updatedAccount = state.account.copyWith(
        totalBalancePaise: newBankBalancePaise,
        lastSyncedAt: now,
      );

      state = state.copyWith(
        account: updatedAccount,
        recentLedger: [incomeResult.ledgerEntry, ...state.recentLedger],
        lastSyncMessage: 'Sync detected incoming money: +₹${delta / 100} added to spendable pool.',
        clearWaterfall: true,
      );
    }
  }

  /// Simulates an in-app payment (e.g. Scan & Pay or Send Money).
  void simulatePayment({required int amountPaise, required String recipient}) {
    if (amountPaise <= 0) {
      throw ArgumentError('Payment amount must be greater than 0.');
    }

    final newBankBalance = state.totalBankBalancePaise - amountPaise;
    simulateBalanceSync(newBankBalance);
  }
}

/// Global provider for the reactive wallet state.
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});
