import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/domain/models/models.dart';
import 'package:bucket_app/domain/engines/goal_analytics_engine.dart';

void main() {
  group('GoalAnalyticsEngine Tests', () {
    final baseDate = DateTime(2026, 10, 1);

    test('computes correct metrics for active goal with deadline', () {
      final bucket = Bucket(
        id: 'laptop',
        name: 'Laptop',
        icon: '💻',
        targetAmountPaise: 8000000, // ₹80,000
        currentAllocationPaise: 3200000, // ₹32,000 (40%)
        deadline: DateTime(2026, 11, 10), // 40 days later
        category: 'Tech',
        type: BucketType.want,
        priority: 4,
        createdAt: baseDate,
        updatedAt: baseDate,
      );

      final report = GoalAnalyticsEngine.analyze(
        bucket: bucket,
        relativeTo: baseDate,
      );

      expect(report.targetAmountPaise, equals(8000000));
      expect(report.currentAmountPaise, equals(3200000));
      expect(report.remainingAmountPaise, equals(4800000)); // ₹48,000 left
      expect(report.percentageComplete, equals(40.0));
      expect(report.isTargetReached, isFalse);
      expect(report.daysRemaining, equals(40));
      expect(report.isOverdue, isFalse);

      // Remaining ₹48,000 / 40 days = ₹1,200/day = 120,000 paise/day
      expect(report.requiredDailyContributionPaise, equals(120000));
      expect(report.requiredWeeklyContributionPaise, equals(120000 * 7));
      expect(report.requiredMonthlyContributionPaise, equals(120000 * 30));
    });

    test('detects reached goal correctly', () {
      final bucket = Bucket(
        id: 'ps5',
        name: 'PS5',
        icon: '🎮',
        targetAmountPaise: 5000000, // ₹50,000
        currentAllocationPaise: 5000000, // ₹50,000
        deadline: DateTime(2026, 12, 31),
        category: 'Gaming',
        type: BucketType.want,
        priority: 1,
        createdAt: baseDate,
        updatedAt: baseDate,
      );

      final report = GoalAnalyticsEngine.analyze(
        bucket: bucket,
        relativeTo: baseDate,
      );

      expect(report.remainingAmountPaise, equals(0));
      expect(report.percentageComplete, equals(100.0));
      expect(report.isTargetReached, isTrue);
      expect(report.isOverdue, isFalse);
    });

    test('detects overdue goal correctly when deadline is in the past', () {
      final bucket = Bucket(
        id: 'shoes',
        name: 'Shoes',
        icon: '👟',
        targetAmountPaise: 500000, // ₹5,000
        currentAllocationPaise: 200000, // ₹2,000 (incomplete)
        deadline: DateTime(2026, 9, 20), // 11 days in the past
        category: 'Shopping',
        type: BucketType.want,
        priority: 2,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      final report = GoalAnalyticsEngine.analyze(
        bucket: bucket,
        relativeTo: baseDate,
      );

      expect(report.isTargetReached, isFalse);
      expect(report.isOverdue, isTrue);
      expect(report.daysRemaining! < 0, isTrue);
    });

    test('forecasts projected completion date based on historical rate', () {
      final bucket = Bucket(
        id: 'fund',
        name: 'Emergency Fund',
        icon: '🛡️',
        targetAmountPaise: 10000000, // ₹1,00,000
        currentAllocationPaise: 2000000, // ₹20,000
        category: 'Savings',
        type: BucketType.need,
        priority: 5,
        createdAt: DateTime(2026, 9, 11),
        updatedAt: baseDate,
      );

      // Ledger: ₹20,000 added over 20 days (Sept 11 to Oct 1) -> ₹1,000/day
      final ledgerEntries = [
        LedgerEntry(
          id: '1',
          bucketId: 'fund',
          transactionType: TransactionType.manualAdd,
          amountDeltaPaise: 2000000,
          balanceAfterPaise: 2000000,
          timestamp: DateTime(2026, 9, 11),
        ),
      ];

      final report = GoalAnalyticsEngine.analyze(
        bucket: bucket,
        ledgerEntries: ledgerEntries,
        relativeTo: baseDate,
      );

      expect(report.averageDailySavingsRatePaise, equals(100000.0)); // ₹1,000/day
      // Remaining ₹80,000 at ₹1,000/day takes 80 days
      expect(report.projectedCompletionDate, isNotNull);
      final daysDiff = report.projectedCompletionDate!.difference(baseDate).inDays;
      expect(daysDiff, equals(80));
    });
  });
}
