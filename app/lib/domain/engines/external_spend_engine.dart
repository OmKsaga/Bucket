import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// Detail of a single bucket affected by waterfall deduction.
class BucketImpact {
  final Bucket originalBucket;
  final Bucket updatedBucket;
  final int deductedAmountPaise;
  final LedgerEntry ledgerEntry;

  const BucketImpact({
    required this.originalBucket,
    required this.updatedBucket,
    required this.deductedAmountPaise,
    required this.ledgerEntry,
  });

  double get deductedRupees => deductedAmountPaise / 100.0;
}

/// Complete result returned by the ExternalSpendEngine waterfall execution.
class WaterfallResult {
  final int totalSpendAmountPaise;
  final int absorbedByUnallocatedPaise;
  final int newUnallocatedPaise;
  final List<BucketImpact> affectedBuckets;
  final List<Bucket> allUpdatedBuckets;
  final List<LedgerEntry> generatedLedgerEntries;
  final int remainingDeficitPaise;
  final bool isDeficit;

  const WaterfallResult({
    required this.totalSpendAmountPaise,
    required this.absorbedByUnallocatedPaise,
    required this.newUnallocatedPaise,
    required this.affectedBuckets,
    required this.allUpdatedBuckets,
    required this.generatedLedgerEntries,
    required this.remainingDeficitPaise,
    required this.isDeficit,
  });

  double get totalSpendRupees => totalSpendAmountPaise / 100.0;
  double get absorbedByUnallocatedRupees => absorbedByUnallocatedPaise / 100.0;
  double get remainingDeficitRupees => remainingDeficitPaise / 100.0;
}

/// Core engine executing the waterfall deduction algorithm when external bank spending occurs.
class ExternalSpendEngine {
  static const _uuid = Uuid();

  /// Executes the multi-step waterfall deduction:
  /// 1. Drains unallocated spendable balance first.
  /// 2. If deficit remains, cascades down unprotected buckets sorted by:
  ///    - Type: WANT before NEED
  ///    - Priority: 1 (lowest) to 5 (highest)
  ///    - CreatedAt: Oldest first
  /// 3. Protected buckets are strictly preserved.
  /// 4. Any leftover unabsorbed spend is recorded as an unallocated deficit.
  static WaterfallResult executeWaterfall({
    required int spendAmountPaise,
    required int unallocatedBalancePaise,
    required List<Bucket> activeBuckets,
    DateTime? timestamp,
  }) {
    if (spendAmountPaise <= 0) {
      throw ArgumentError.value(spendAmountPaise, 'spendAmountPaise', 'Spend amount must be greater than 0.');
    }

    final effectiveTimestamp = timestamp ?? DateTime.now();

    // Step 1: Absorb from unallocated balance first
    final absorbedByUnallocated = min(max(0, unallocatedBalancePaise), spendAmountPaise);
    int remainingDeficit = spendAmountPaise - absorbedByUnallocated;
    int newUnallocated = unallocatedBalancePaise - absorbedByUnallocated;

    final List<BucketImpact> affectedBuckets = [];
    final List<LedgerEntry> generatedEntries = [];
    final Map<String, Bucket> bucketMap = {for (final b in activeBuckets) b.id: b};

    // If unallocated fully absorbed the spend, we are done
    if (remainingDeficit == 0) {
      return WaterfallResult(
        totalSpendAmountPaise: spendAmountPaise,
        absorbedByUnallocatedPaise: absorbedByUnallocated,
        newUnallocatedPaise: newUnallocated,
        affectedBuckets: const [],
        allUpdatedBuckets: activeBuckets,
        generatedLedgerEntries: const [],
        remainingDeficitPaise: 0,
        isDeficit: false,
      );
    }

    // Step 2: Waterfall across eligible buckets
    final eligibleBuckets = getDeductionOrder(activeBuckets);

    for (final bucket in eligibleBuckets) {
      if (remainingDeficit == 0) break;

      final currentAlloc = bucket.currentAllocationPaise;
      final deductAmount = min(currentAlloc, remainingDeficit);

      if (deductAmount > 0) {
        final newAlloc = currentAlloc - deductAmount;
        final updatedBucket = bucket.copyWith(
          currentAllocationPaise: newAlloc,
          isCompleted: newAlloc >= bucket.targetAmountPaise,
          updatedAt: effectiveTimestamp,
        );

        final entry = LedgerEntry(
          id: _uuid.v4(),
          bucketId: bucket.id,
          transactionType: TransactionType.externalSpendImpact,
          amountDeltaPaise: -deductAmount,
          balanceAfterPaise: newAlloc,
          note: 'Auto-deducted ₹${deductAmount / 100} for external spending',
          timestamp: effectiveTimestamp,
        );

        affectedBuckets.add(BucketImpact(
          originalBucket: bucket,
          updatedBucket: updatedBucket,
          deductedAmountPaise: deductAmount,
          ledgerEntry: entry,
        ));

        generatedEntries.add(entry);
        bucketMap[bucket.id] = updatedBucket;
        remainingDeficit -= deductAmount;
      }
    }

    // Step 3: Handle leftover deficit (if all unallocated & unprotected buckets exhausted)
    final bool isDeficit = remainingDeficit > 0;
    if (isDeficit) {
      newUnallocated -= remainingDeficit;
    }

    return WaterfallResult(
      totalSpendAmountPaise: spendAmountPaise,
      absorbedByUnallocatedPaise: absorbedByUnallocated,
      newUnallocatedPaise: newUnallocated,
      affectedBuckets: affectedBuckets,
      allUpdatedBuckets: bucketMap.values.toList(),
      generatedLedgerEntries: generatedEntries,
      remainingDeficitPaise: remainingDeficit,
      isDeficit: isDeficit,
    );
  }

  /// Sorts buckets in the strict deduction priority sequence:
  /// 1. Only unprotected buckets with balance > 0
  /// 2. Category: WANT (0) before NEED (1)
  /// 3. Priority: 1 (Lowest) before 5 (Highest)
  /// 4. Timestamp: Oldest before newest
  static List<Bucket> getDeductionOrder(List<Bucket> buckets) {
    final eligible = buckets.where((b) => !b.isProtected && b.currentAllocationPaise > 0).toList();

    eligible.sort((a, b) {
      // 1. WANT before NEED
      final aTypeOrder = a.type == BucketType.want ? 0 : 1;
      final bTypeOrder = b.type == BucketType.want ? 0 : 1;
      if (aTypeOrder != bTypeOrder) {
        return aTypeOrder.compareTo(bTypeOrder);
      }

      // 2. Priority ASC (1 to 5)
      if (a.priority != b.priority) {
        return a.priority.compareTo(b.priority);
      }

      // 3. CreatedAt ASC (older first)
      return a.createdAt.compareTo(b.createdAt);
    });

    return eligible;
  }
}
