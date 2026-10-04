import 'dart:math';
import '../models/models.dart';
import '../engines/external_spend_engine.dart';

enum PaymentSafetyStatus {
  safe,
  warningOverspend,
  criticalDeficit,
}

/// Predicted impact on a specific bucket if payment proceeds.
class PredictedBucketImpact {
  final Bucket bucket;
  final int predictedDeductionPaise;
  final int predictedNewBalancePaise;

  const PredictedBucketImpact({
    required this.bucket,
    required this.predictedDeductionPaise,
    required this.predictedNewBalancePaise,
  });

  double get predictedDeductionRupees => predictedDeductionPaise / 100.0;
  double get predictedNewBalanceRupees => predictedNewBalancePaise / 100.0;
}

/// Evaluation result returned by PaymentWarningService.
class PaymentWarningEvaluation {
  final int paymentAmountPaise;
  final int spendableBalancePaise;
  final PaymentSafetyStatus status;
  final bool exceedsSpendable;
  final int deficitPaise;
  final List<PredictedBucketImpact> predictedImpactedBuckets;
  final List<Bucket> preservedProtectedBuckets;
  final String title;
  final String description;

  const PaymentWarningEvaluation({
    required this.paymentAmountPaise,
    required this.spendableBalancePaise,
    required this.status,
    required this.exceedsSpendable,
    required this.deficitPaise,
    required this.predictedImpactedBuckets,
    required this.preservedProtectedBuckets,
    required this.title,
    required this.description,
  });

  double get paymentRupees => paymentAmountPaise / 100.0;
  double get spendableRupees => spendableBalancePaise / 100.0;
  double get deficitRupees => deficitPaise / 100.0;
}

/// Service evaluating pre-payment impact against virtual goal buckets.
class PaymentWarningService {
  /// Evaluates the impact of a transaction before the user authorizes payment.
  static PaymentWarningEvaluation evaluate({
    required int amountPaise,
    required int spendableBalancePaise,
    required List<Bucket> activeBuckets,
  }) {
    if (amountPaise <= 0) {
      throw ArgumentError.value(amountPaise, 'amountPaise', 'Amount must be greater than 0');
    }

    final exceeds = amountPaise > spendableBalancePaise;

    if (!exceeds) {
      return PaymentWarningEvaluation(
        paymentAmountPaise: amountPaise,
        spendableBalancePaise: spendableBalancePaise,
        status: PaymentSafetyStatus.safe,
        exceedsSpendable: false,
        deficitPaise: 0,
        predictedImpactedBuckets: const [],
        preservedProtectedBuckets: activeBuckets.where((b) => b.isProtected).toList(),
        title: 'Safe to Spend',
        description: 'This transaction is completely within your unallocated spendable balance of ₹${(spendableBalancePaise / 100).toStringAsFixed(0)}.',
      );
    }

    final int deficit = amountPaise - (spendableBalancePaise > 0 ? spendableBalancePaise : 0);

    // Run hypothetical waterfall to project impact
    final waterfall = ExternalSpendEngine.executeWaterfall(
      spendAmountPaise: amountPaise,
      unallocatedBalancePaise: spendableBalancePaise,
      activeBuckets: activeBuckets,
    );

    final predictedList = waterfall.affectedBuckets.map((impact) {
      return PredictedBucketImpact(
        bucket: impact.originalBucket,
        predictedDeductionPaise: impact.deductedAmountPaise,
        predictedNewBalancePaise: impact.updatedBucket.currentAllocationPaise,
      );
    }).toList();

    final preservedProtected = activeBuckets.where((b) => b.isProtected && b.currentAllocationPaise > 0).toList();

    final isCritical = waterfall.isDeficit;

    String desc;
    if (predictedList.isNotEmpty) {
      final first = predictedList.first;
      desc = 'Exceeds spendable balance by ₹${(deficit / 100).toStringAsFixed(0)}. '
          'Expected to impact: ${first.bucket.icon} ${first.bucket.name} (P${first.bucket.priority}).';
      if (predictedList.length > 1) {
        desc += ' and ${predictedList.length - 1} other goal(s).';
      }
    } else {
      desc = 'Exceeds spendable balance by ₹${(deficit / 100).toStringAsFixed(0)}. All eligible goals are either protected or depleted.';
    }

    return PaymentWarningEvaluation(
      paymentAmountPaise: amountPaise,
      spendableBalancePaise: spendableBalancePaise,
      status: isCritical ? PaymentSafetyStatus.criticalDeficit : PaymentSafetyStatus.warningOverspend,
      exceedsSpendable: true,
      deficitPaise: deficit,
      predictedImpactedBuckets: predictedList,
      preservedProtectedBuckets: preservedProtected,
      title: isCritical ? 'Critical Deficit Warning' : 'Committed Funds Warning',
      description: desc,
    );
  }
}
