import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// Result returned by AllocationEngine.allocate().
class AllocationResult {
  final Bucket updatedBucket;
  final LedgerEntry ledgerEntry;
  final int updatedUnallocatedPaise;

  const AllocationResult({
    required this.updatedBucket,
    required this.ledgerEntry,
    required this.updatedUnallocatedPaise,
  });
}

/// Result returned by AllocationEngine.deallocate().
class DeallocationResult {
  final Bucket updatedBucket;
  final LedgerEntry ledgerEntry;
  final int updatedUnallocatedPaise;

  const DeallocationResult({
    required this.updatedBucket,
    required this.ledgerEntry,
    required this.updatedUnallocatedPaise,
  });
}

/// Result returned by AllocationEngine.reallocate().
class ReallocationResult {
  final Bucket updatedSourceBucket;
  final Bucket updatedTargetBucket;
  final LedgerEntry sourceLedgerEntry;
  final LedgerEntry targetLedgerEntry;

  const ReallocationResult({
    required this.updatedSourceBucket,
    required this.updatedTargetBucket,
    required this.sourceLedgerEntry,
    required this.targetLedgerEntry,
  });
}

/// Core engine managing virtual money allocations and invariant enforcement.
class AllocationEngine {
  static const _uuid = Uuid();

  /// Allocates spendable money to a bucket.
  /// Enforces: amount > 0 and amount <= unallocatedBalancePaise.
  static AllocationResult allocate({
    required Bucket bucket,
    required int amountPaise,
    required int currentUnallocatedPaise,
    String? note,
    DateTime? timestamp,
  }) {
    if (amountPaise <= 0) {
      throw ArgumentError.value(amountPaise, 'amountPaise', 'Allocation amount must be strictly greater than 0.');
    }
    if (amountPaise > currentUnallocatedPaise) {
      throw StateError(
        'Insufficient spendable funds. Cannot allocate ₹${amountPaise / 100} when spendable balance is ₹${currentUnallocatedPaise / 100}.',
      );
    }

    final effectiveTimestamp = timestamp ?? DateTime.now();
    final newAllocation = bucket.currentAllocationPaise + amountPaise;
    final isFirstAllocation = bucket.currentAllocationPaise == 0;

    final updatedBucket = bucket.copyWith(
      currentAllocationPaise: newAllocation,
      isCompleted: newAllocation >= bucket.targetAmountPaise,
      updatedAt: effectiveTimestamp,
    );

    final ledgerEntry = LedgerEntry(
      id: _uuid.v4(),
      bucketId: bucket.id,
      transactionType: isFirstAllocation ? TransactionType.initialAllocation : TransactionType.manualAdd,
      amountDeltaPaise: amountPaise,
      balanceAfterPaise: newAllocation,
      note: note ?? (isFirstAllocation ? 'Initial allocation to ${bucket.name}' : 'Added funds to ${bucket.name}'),
      timestamp: effectiveTimestamp,
    );

    return AllocationResult(
      updatedBucket: updatedBucket,
      ledgerEntry: ledgerEntry,
      updatedUnallocatedPaise: currentUnallocatedPaise - amountPaise,
    );
  }

  /// Deallocates money from a bucket, returning it to the spendable unallocated pool.
  /// Enforces: amount > 0 and amount <= bucket.currentAllocationPaise.
  static DeallocationResult deallocate({
    required Bucket bucket,
    required int amountPaise,
    required int currentUnallocatedPaise,
    String? note,
    DateTime? timestamp,
  }) {
    if (amountPaise <= 0) {
      throw ArgumentError.value(amountPaise, 'amountPaise', 'Deallocation amount must be strictly greater than 0.');
    }
    if (amountPaise > bucket.currentAllocationPaise) {
      throw StateError(
        'Cannot deallocate ₹${amountPaise / 100} from ${bucket.name} which only has ₹${bucket.currentRupees}.',
      );
    }

    final effectiveTimestamp = timestamp ?? DateTime.now();
    final newAllocation = bucket.currentAllocationPaise - amountPaise;

    final updatedBucket = bucket.copyWith(
      currentAllocationPaise: newAllocation,
      isCompleted: newAllocation >= bucket.targetAmountPaise,
      updatedAt: effectiveTimestamp,
    );

    final ledgerEntry = LedgerEntry(
      id: _uuid.v4(),
      bucketId: bucket.id,
      transactionType: TransactionType.manualRemove,
      amountDeltaPaise: -amountPaise,
      balanceAfterPaise: newAllocation,
      note: note ?? 'Withdrew funds from ${bucket.name} to spendable pool',
      timestamp: effectiveTimestamp,
    );

    return DeallocationResult(
      updatedBucket: updatedBucket,
      ledgerEntry: ledgerEntry,
      updatedUnallocatedPaise: currentUnallocatedPaise + amountPaise,
    );
  }

  /// Reallocates virtual funds from one bucket directly to another.
  /// This is an internal accounting adjustment; unallocated bank balance remains unchanged.
  static ReallocationResult reallocate({
    required Bucket fromBucket,
    required Bucket toBucket,
    required int amountPaise,
    String? note,
    DateTime? timestamp,
  }) {
    if (fromBucket.id == toBucket.id) {
      throw ArgumentError('Source and target buckets cannot be identical.');
    }
    if (amountPaise <= 0) {
      throw ArgumentError.value(amountPaise, 'amountPaise', 'Reallocation amount must be strictly greater than 0.');
    }
    if (amountPaise > fromBucket.currentAllocationPaise) {
      throw StateError(
        'Cannot reallocate ₹${amountPaise / 100} from ${fromBucket.name} which only has ₹${fromBucket.currentRupees}.',
      );
    }

    final effectiveTimestamp = timestamp ?? DateTime.now();
    final sourceNewAllocation = fromBucket.currentAllocationPaise - amountPaise;
    final targetNewAllocation = toBucket.currentAllocationPaise + amountPaise;

    final updatedSource = fromBucket.copyWith(
      currentAllocationPaise: sourceNewAllocation,
      isCompleted: sourceNewAllocation >= fromBucket.targetAmountPaise,
      updatedAt: effectiveTimestamp,
    );

    final updatedTarget = toBucket.copyWith(
      currentAllocationPaise: targetNewAllocation,
      isCompleted: targetNewAllocation >= toBucket.targetAmountPaise,
      updatedAt: effectiveTimestamp,
    );

    final transferRef = 'realloc_${_uuid.v4().substring(0, 8)}';

    final sourceEntry = LedgerEntry(
      id: _uuid.v4(),
      bucketId: fromBucket.id,
      transactionType: TransactionType.reallocation,
      amountDeltaPaise: -amountPaise,
      balanceAfterPaise: sourceNewAllocation,
      referenceId: transferRef,
      note: note ?? 'Reallocated ₹${amountPaise / 100} to ${toBucket.name}',
      timestamp: effectiveTimestamp,
    );

    final targetEntry = LedgerEntry(
      id: _uuid.v4(),
      bucketId: toBucket.id,
      transactionType: TransactionType.reallocation,
      amountDeltaPaise: amountPaise,
      balanceAfterPaise: targetNewAllocation,
      referenceId: transferRef,
      note: note ?? 'Reallocated ₹${amountPaise / 100} from ${fromBucket.name}',
      timestamp: effectiveTimestamp,
    );

    return ReallocationResult(
      updatedSourceBucket: updatedSource,
      updatedTargetBucket: updatedTarget,
      sourceLedgerEntry: sourceEntry,
      targetLedgerEntry: targetEntry,
    );
  }

  /// Calculates the true balance of a bucket derived from append-only ledger entries.
  static int computeDerivedBalance(List<LedgerEntry> entries, String bucketId) {
    return entries
        .where((e) => e.bucketId == bucketId)
        .fold<int>(0, (sum, entry) => sum + entry.amountDeltaPaise);
  }
}
