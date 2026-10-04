import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/domain/models/models.dart';
import 'package:bucket_app/domain/engines/external_spend_engine.dart';

void main() {
  group('ExternalSpendEngine Waterfall Deduction Tests', () {
    final now = DateTime(2026, 10, 1);

    late Bucket p1Want;
    late Bucket p2Want;
    late Bucket p4Want;
    late Bucket p5NeedProtected;
    late Bucket p3Need;

    setUp(() {
      p1Want = Bucket(
        id: 'ps5',
        name: 'PS5',
        icon: '🎮',
        targetAmountPaise: 5000000,
        currentAllocationPaise: 700000, // ₹7,000
        category: 'Gaming',
        type: BucketType.want,
        priority: 1, // Lowest priority -> 1st to sacrifice
        createdAt: now,
        updatedAt: now,
      );

      p2Want = Bucket(
        id: 'shoes',
        name: 'Shoes',
        icon: '👟',
        targetAmountPaise: 1000000,
        currentAllocationPaise: 500000, // ₹5,000
        category: 'Shopping',
        type: BucketType.want,
        priority: 2,
        createdAt: now,
        updatedAt: now,
      );

      p4Want = Bucket(
        id: 'laptop',
        name: 'Laptop',
        icon: '💻',
        targetAmountPaise: 8000000,
        currentAllocationPaise: 800000, // ₹8,000
        category: 'Tech',
        type: BucketType.want,
        priority: 4,
        createdAt: now,
        updatedAt: now,
      );

      p3Need = Bucket(
        id: 'bike',
        name: 'Bike Service',
        icon: '🛵',
        targetAmountPaise: 400000,
        currentAllocationPaise: 300000, // ₹3,000
        category: 'Transport',
        type: BucketType.need,
        priority: 3,
        createdAt: now,
        updatedAt: now,
      );

      p5NeedProtected = Bucket(
        id: 'rent',
        name: 'Rent',
        icon: '🏠',
        targetAmountPaise: 1000000,
        currentAllocationPaise: 1000000, // ₹10,000
        category: 'Housing',
        type: BucketType.need,
        priority: 5,
        isProtected: true, // PROTECTED
        createdAt: now,
        updatedAt: now,
      );
    });

    test('spend absorbed entirely by unallocated balance touches zero buckets', () {
      final buckets = [p1Want, p2Want, p4Want, p5NeedProtected];
      final result = ExternalSpendEngine.executeWaterfall(
        spendAmountPaise: 200000, // ₹2,000 spend
        unallocatedBalancePaise: 500000, // ₹5,000 unallocated
        activeBuckets: buckets,
      );

      expect(result.absorbedByUnallocatedPaise, equals(200000));
      expect(result.newUnallocatedPaise, equals(300000));
      expect(result.affectedBuckets, isEmpty);
      expect(result.generatedLedgerEntries, isEmpty);
      expect(result.isDeficit, isFalse);
    });

    test('spend drains unallocated first, then deducts lowest priority bucket (P1 WANT)', () {
      final buckets = [p1Want, p2Want, p4Want, p5NeedProtected];
      // Spend ₹6,000. Unallocated has ₹2,000.
      // Need ₹4,000 from buckets.
      // Lowest eligible is PS5 (₹7,000 available).
      // PS5 absorbs full ₹4,000 -> balance becomes ₹3,000.
      final result = ExternalSpendEngine.executeWaterfall(
        spendAmountPaise: 600000, // ₹6,000
        unallocatedBalancePaise: 200000, // ₹2,000
        activeBuckets: buckets,
      );

      expect(result.absorbedByUnallocatedPaise, equals(200000));
      expect(result.newUnallocatedPaise, equals(0));
      expect(result.affectedBuckets.length, equals(1));

      final ps5Impact = result.affectedBuckets.first;
      expect(ps5Impact.originalBucket.id, equals('ps5'));
      expect(ps5Impact.deductedAmountPaise, equals(400000)); // ₹4,000
      expect(ps5Impact.updatedBucket.currentAllocationPaise, equals(300000)); // ₹3,000 left
      expect(result.isDeficit, isFalse);
    });

    test('multi-bucket overflow drains P1 completely and spills into P2', () {
      final buckets = [p1Want, p2Want, p4Want, p5NeedProtected];
      // Unallocated is ₹0. Spend is ₹10,000.
      // PS5 (₹7,000) drained to 0.
      // Remaining ₹3,000 spills into Shoes (₹5,000) -> Shoes becomes ₹2,000.
      final result = ExternalSpendEngine.executeWaterfall(
        spendAmountPaise: 1000000, // ₹10,000
        unallocatedBalancePaise: 0,
        activeBuckets: buckets,
      );

      expect(result.affectedBuckets.length, equals(2));
      expect(result.affectedBuckets[0].originalBucket.id, equals('ps5'));
      expect(result.affectedBuckets[0].deductedAmountPaise, equals(700000));
      expect(result.affectedBuckets[0].updatedBucket.currentAllocationPaise, equals(0));

      expect(result.affectedBuckets[1].originalBucket.id, equals('shoes'));
      expect(result.affectedBuckets[1].deductedAmountPaise, equals(300000));
      expect(result.affectedBuckets[1].updatedBucket.currentAllocationPaise, equals(200000));

      expect(result.isDeficit, isFalse);
    });

    test('WANT buckets are drained before NEED buckets even if priority is higher', () {
      // p3Need is Priority 3 NEED (₹3,000).
      // p4Want is Priority 4 WANT (₹8,000).
      // Rule: ALL WANTs must be drained before ANY NEED is touched.
      final buckets = [p3Need, p4Want];
      final result = ExternalSpendEngine.executeWaterfall(
        spendAmountPaise: 500000, // ₹5,000
        unallocatedBalancePaise: 0,
        activeBuckets: buckets,
      );

      // Even though p4Want has priority 4 > p3Need priority 3, p4 is a WANT, so it drains first!
      expect(result.affectedBuckets.length, equals(1));
      expect(result.affectedBuckets.first.originalBucket.id, equals('laptop'));
      expect(result.affectedBuckets.first.deductedAmountPaise, equals(500000));
      expect(result.affectedBuckets.first.updatedBucket.currentAllocationPaise, equals(300000));
    });

    test('protected buckets are strictly preserved under all circumstances', () {
      // Buckets: only Rent (P5 NEED, Protected, ₹10,000).
      // Spend: ₹5,000. Unallocated: ₹0.
      // Expected: Rent is NOT touched. Deficit of ₹5,000 reported.
      final buckets = [p5NeedProtected];
      final result = ExternalSpendEngine.executeWaterfall(
        spendAmountPaise: 500000, // ₹5,000
        unallocatedBalancePaise: 0,
        activeBuckets: buckets,
      );

      expect(result.affectedBuckets, isEmpty);
      expect(result.isDeficit, isTrue);
      expect(result.remainingDeficitPaise, equals(500000));
      expect(result.newUnallocatedPaise, equals(-500000)); // Negative unallocated pool
    });

    test('zero-balance buckets are skipped during deduction', () {
      final emptyBucket = p1Want.copyWith(currentAllocationPaise: 0);
      final buckets = [emptyBucket, p2Want];

      final result = ExternalSpendEngine.executeWaterfall(
        spendAmountPaise: 200000, // ₹2,000
        unallocatedBalancePaise: 0,
        activeBuckets: buckets,
      );

      // Skipped emptyBucket and deducted from p2Want directly
      expect(result.affectedBuckets.length, equals(1));
      expect(result.affectedBuckets.first.originalBucket.id, equals('shoes'));
      expect(result.affectedBuckets.first.deductedAmountPaise, equals(200000));
    });
  });
}
