import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/domain/models/models.dart';
import 'package:bucket_app/domain/services/payment_warning_service.dart';

void main() {
  group('PaymentWarningService Tests', () {
    final now = DateTime(2026, 10, 1);

    late Bucket p1Want;
    late Bucket p2Want;
    late Bucket p5NeedProtected;

    setUp(() {
      p1Want = Bucket(
        id: 'ps5',
        name: 'PS5',
        icon: '🎮',
        targetAmountPaise: 5000000,
        currentAllocationPaise: 700000, // ₹7,000
        category: 'Gaming',
        type: BucketType.want,
        priority: 1, // First to drain
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

      p5NeedProtected = Bucket(
        id: 'rent',
        name: 'Rent',
        icon: '🏠',
        targetAmountPaise: 1000000,
        currentAllocationPaise: 1000000, // ₹10,000
        category: 'Housing',
        type: BucketType.need,
        priority: 5,
        isProtected: true,
        createdAt: now,
        updatedAt: now,
      );
    });

    test('payment within spendable balance is marked safe', () {
      final evaluation = PaymentWarningService.evaluate(
        amountPaise: 200000, // ₹2,000
        spendableBalancePaise: 500000, // ₹5,000 spendable
        activeBuckets: [p1Want, p2Want, p5NeedProtected],
      );

      expect(evaluation.status, equals(PaymentSafetyStatus.safe));
      expect(evaluation.exceedsSpendable, isFalse);
      expect(evaluation.deficitPaise, equals(0));
      expect(evaluation.predictedImpactedBuckets, isEmpty);
    });

    test('payment exceeding spendable balance warns and predicts lowest priority bucket impact', () {
      final evaluation = PaymentWarningService.evaluate(
        amountPaise: 600000, // ₹6,000
        spendableBalancePaise: 200000, // ₹2,000 spendable
        activeBuckets: [p1Want, p2Want, p5NeedProtected],
      );

      expect(evaluation.status, equals(PaymentSafetyStatus.warningOverspend));
      expect(evaluation.exceedsSpendable, isTrue);
      expect(evaluation.deficitPaise, equals(400000)); // ₹4,000 deficit

      // Predicts impact on PS5 (₹7,000)
      expect(evaluation.predictedImpactedBuckets.length, equals(1));
      expect(evaluation.predictedImpactedBuckets.first.bucket.id, equals('ps5'));
      expect(evaluation.predictedImpactedBuckets.first.predictedDeductionPaise, equals(400000));
      expect(evaluation.predictedImpactedBuckets.first.predictedNewBalancePaise, equals(300000));
    });

    test('critical deficit flagged when payment exceeds spendable and all unprotected goals', () {
      // PS5 (₹7k) + Shoes (₹5k) = ₹12k unprotected funds.
      // Payment: ₹20,000. Spendable: ₹0.
      // Rent (₹10k) is protected and preserved.
      final evaluation = PaymentWarningService.evaluate(
        amountPaise: 2000000, // ₹20,000
        spendableBalancePaise: 0,
        activeBuckets: [p1Want, p2Want, p5NeedProtected],
      );

      expect(evaluation.status, equals(PaymentSafetyStatus.criticalDeficit));
      expect(evaluation.exceedsSpendable, isTrue);
      // PS5 (₹7k) and Shoes (₹5k) absorbed ₹12k. Remaining deficit is ₹8k.
      expect(evaluation.preservedProtectedBuckets.first.id, equals('rent'));
    });
  });
}
