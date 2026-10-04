import '../models/models.dart';

/// Analytics report for an individual goal bucket.
class GoalAnalyticsReport {
  final String bucketId;
  final String bucketName;
  final int targetAmountPaise;
  final int currentAmountPaise;
  final int remainingAmountPaise;
  final double percentageComplete;
  final bool isTargetReached;
  final int? daysRemaining;
  final bool isOverdue;
  final int? requiredDailyContributionPaise;
  final int? requiredWeeklyContributionPaise;
  final int? requiredMonthlyContributionPaise;
  final double? averageDailySavingsRatePaise;
  final DateTime? projectedCompletionDate;

  const GoalAnalyticsReport({
    required this.bucketId,
    required this.bucketName,
    required this.targetAmountPaise,
    required this.currentAmountPaise,
    required this.remainingAmountPaise,
    required this.percentageComplete,
    required this.isTargetReached,
    this.daysRemaining,
    required this.isOverdue,
    this.requiredDailyContributionPaise,
    this.requiredWeeklyContributionPaise,
    this.requiredMonthlyContributionPaise,
    this.averageDailySavingsRatePaise,
    this.projectedCompletionDate,
  });

  double get targetRupees => targetAmountPaise / 100.0;
  double get currentRupees => currentAmountPaise / 100.0;
  double get remainingRupees => remainingAmountPaise / 100.0;
  double? get requiredDailyRupees =>
      requiredDailyContributionPaise != null ? requiredDailyContributionPaise! / 100.0 : null;
  double? get requiredWeeklyRupees =>
      requiredWeeklyContributionPaise != null ? requiredWeeklyContributionPaise! / 100.0 : null;
  double? get requiredMonthlyRupees =>
      requiredMonthlyContributionPaise != null ? requiredMonthlyContributionPaise! / 100.0 : null;
}

/// Core engine computing goal metrics, contribution targets, and project completion forecasts.
class GoalAnalyticsEngine {
  /// Computes goal analytics for a bucket.
  /// Optionally uses ledgerEntries to calculate historical savings rates.
  static GoalAnalyticsReport analyze({
    required Bucket bucket,
    List<LedgerEntry>? ledgerEntries,
    DateTime? relativeTo,
  }) {
    final now = relativeTo ?? DateTime.now();
    final current = bucket.currentAllocationPaise;
    final target = bucket.targetAmountPaise;
    final remaining = target > current ? target - current : 0;
    final bool reached = current >= target;
    final double percentage = target > 0 ? ((current / target) * 100.0).clamp(0.0, 100.0) : 100.0;

    int? daysRemaining;
    bool overdue = false;
    int? dailyReq;
    int? weeklyReq;
    int? monthlyReq;

    if (bucket.deadline != null) {
      final diff = bucket.deadline!.difference(now);
      daysRemaining = diff.inDays;

      if (daysRemaining < 0 && !reached) {
        overdue = true;
      } else if (daysRemaining > 0 && remaining > 0) {
        // Daily required = ceiling division in paise
        dailyReq = (remaining / daysRemaining).ceil();
        weeklyReq = dailyReq * 7;
        monthlyReq = dailyReq * 30;
      } else if (daysRemaining == 0 && remaining > 0) {
        dailyReq = remaining;
        weeklyReq = remaining;
        monthlyReq = remaining;
      }
    }

    // Historical savings rate calculation
    double? avgDailyRate;
    DateTime? projectedDate;

    if (ledgerEntries != null && ledgerEntries.isNotEmpty) {
      final bucketEntries = ledgerEntries.where((e) => e.bucketId == bucket.id).toList();

      if (bucketEntries.isNotEmpty) {
        bucketEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final firstTime = bucketEntries.first.timestamp;
        final elapsedDays = now.difference(firstTime).inDays;

        final totalAdded = bucketEntries
            .where((e) => e.amountDeltaPaise > 0)
            .fold<int>(0, (sum, e) => sum + e.amountDeltaPaise);

        if (elapsedDays >= 1 && totalAdded > 0) {
          avgDailyRate = totalAdded / elapsedDays;

          if (avgDailyRate > 0 && remaining > 0) {
            final daysNeeded = (remaining / avgDailyRate).ceil();
            projectedDate = now.add(Duration(days: daysNeeded));
          }
        }
      }
    }

    return GoalAnalyticsReport(
      bucketId: bucket.id,
      bucketName: bucket.name,
      targetAmountPaise: target,
      currentAmountPaise: current,
      remainingAmountPaise: remaining,
      percentageComplete: double.parse(percentage.toStringAsFixed(1)),
      isTargetReached: reached,
      daysRemaining: daysRemaining,
      isOverdue: overdue,
      requiredDailyContributionPaise: dailyReq,
      requiredWeeklyContributionPaise: weeklyReq,
      requiredMonthlyContributionPaise: monthlyReq,
      averageDailySavingsRatePaise: avgDailyRate,
      projectedCompletionDate: projectedDate,
    );
  }
}
