import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/domain/models/models.dart';
import 'package:bucket_app/domain/engines/allocation_engine.dart';

void main() {
  group('AllocationEngine Tests', () {
    late Bucket testBucket;
    final now = DateTime(2026, 10, 1);

    setUp(() {
      testBucket = Bucket(
        id: 'b1',
        name: 'PS5',
        icon: '🎮',
        targetAmountPaise: 5000000, // ₹50,000
        currentAllocationPaise: 1000000, // ₹10,000
        category: 'Gaming',
        type: BucketType.want,
        priority: 1,
        createdAt: now,
        updatedAt: now,
      );
    });

    test('allocate within spendable balance succeeds', () {
      final result = AllocationEngine.allocate(
        bucket: testBucket,
        amountPaise: 500000, // ₹5,000
        currentUnallocatedPaise: 1000000, // ₹10,000 available
      );

      expect(result.updatedBucket.currentAllocationPaise, equals(1500000)); // ₹15,000
      expect(result.updatedUnallocatedPaise, equals(500000)); // ₹5,000 left
      expect(result.ledgerEntry.amountDeltaPaise, equals(500000));
      expect(result.ledgerEntry.transactionType, equals(TransactionType.manualAdd));
    });

    test('allocate exceeding spendable balance throws StateError', () {
      expect(
        () => AllocationEngine.allocate(
          bucket: testBucket,
          amountPaise: 1500000, // ₹15,000
          currentUnallocatedPaise: 500000, // only ₹5,000 available
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allocate zero or negative amount throws ArgumentError', () {
      expect(
        () => AllocationEngine.allocate(
          bucket: testBucket,
          amountPaise: 0,
          currentUnallocatedPaise: 500000,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => AllocationEngine.allocate(
          bucket: testBucket,
          amountPaise: -100,
          currentUnallocatedPaise: 500000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deallocate valid amount returns funds to spendable', () {
      final result = AllocationEngine.deallocate(
        bucket: testBucket,
        amountPaise: 400000, // ₹4,000
        currentUnallocatedPaise: 200000, // ₹2,000
      );

      expect(result.updatedBucket.currentAllocationPaise, equals(600000)); // ₹6,000
      expect(result.updatedUnallocatedPaise, equals(600000)); // ₹2k + ₹4k = ₹6k
      expect(result.ledgerEntry.amountDeltaPaise, equals(-400000));
      expect(result.ledgerEntry.transactionType, equals(TransactionType.manualRemove));
    });

    test('deallocate exceeding bucket balance throws StateError', () {
      expect(
        () => AllocationEngine.deallocate(
          bucket: testBucket,
          amountPaise: 2000000, // ₹20,000 (bucket only has ₹10,000)
          currentUnallocatedPaise: 0,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('reallocate moves funds virtually between two buckets', () {
      final targetBucket = Bucket(
        id: 'b2',
        name: 'Laptop',
        icon: '💻',
        targetAmountPaise: 8000000,
        currentAllocationPaise: 2000000,
        category: 'Work',
        type: BucketType.want,
        priority: 4,
        createdAt: now,
        updatedAt: now,
      );

      final result = AllocationEngine.reallocate(
        fromBucket: testBucket, // has ₹10,000
        toBucket: targetBucket, // has ₹20,000
        amountPaise: 300000, // ₹3,000
      );

      expect(result.updatedSourceBucket.currentAllocationPaise, equals(700000)); // ₹7,000
      expect(result.updatedTargetBucket.currentAllocationPaise, equals(2300000)); // ₹23,000
      expect(result.sourceLedgerEntry.amountDeltaPaise, equals(-300000));
      expect(result.targetLedgerEntry.amountDeltaPaise, equals(300000));
      expect(result.sourceLedgerEntry.referenceId, equals(result.targetLedgerEntry.referenceId));
    });

    test('reallocate to same bucket throws ArgumentError', () {
      expect(
        () => AllocationEngine.reallocate(
          fromBucket: testBucket,
          toBucket: testBucket,
          amountPaise: 1000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('computeDerivedBalance correctly sums ledger history', () {
      final entries = [
        LedgerEntry(
          id: '1',
          bucketId: 'b1',
          transactionType: TransactionType.initialAllocation,
          amountDeltaPaise: 100000, // +₹1,000
          balanceAfterPaise: 100000,
          timestamp: now,
        ),
        LedgerEntry(
          id: '2',
          bucketId: 'b1',
          transactionType: TransactionType.manualAdd,
          amountDeltaPaise: 50000, // +₹500
          balanceAfterPaise: 150000,
          timestamp: now,
        ),
        LedgerEntry(
          id: '3',
          bucketId: 'b1',
          transactionType: TransactionType.manualRemove,
          amountDeltaPaise: -30000, // -₹300
          balanceAfterPaise: 120000,
          timestamp: now,
        ),
        LedgerEntry(
          id: '4',
          bucketId: 'b2', // Other bucket
          transactionType: TransactionType.manualAdd,
          amountDeltaPaise: 999999,
          balanceAfterPaise: 999999,
          timestamp: now,
        ),
      ];

      final derived = AllocationEngine.computeDerivedBalance(entries, 'b1');
      expect(derived, equals(120000)); // ₹1,200
    });
  });
}
