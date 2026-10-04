import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engines/goal_analytics_engine.dart';
import '../../../domain/models/models.dart';
import '../../shared/wallet_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final buckets = wallet.buckets;
    final ledger = wallet.recentLedger;

    // Calculate aggregated portfolio stats
    final totalTargetPaise = buckets.fold<int>(0, (sum, b) => sum + b.targetAmountPaise);
    final totalAllocatedPaise = wallet.totalAllocatedPaise;
    final overallProgress = totalTargetPaise > 0
        ? ((totalAllocatedPaise / totalTargetPaise) * 100).clamp(0.0, 100.0)
        : 100.0;

    // NEED vs WANT breakdown
    final needBuckets = buckets.where((b) => b.type == BucketType.need);
    final wantBuckets = buckets.where((b) => b.type == BucketType.want);
    final needAllocatedPaise = needBuckets.fold<int>(0, (sum, b) => sum + b.currentAllocationPaise);
    final wantAllocatedPaise = wantBuckets.fold<int>(0, (sum, b) => sum + b.currentAllocationPaise);
    final needPercent = totalAllocatedPaise > 0 ? (needAllocatedPaise / totalAllocatedPaise) * 100 : 50.0;
    final wantPercent = totalAllocatedPaise > 0 ? (wantAllocatedPaise / totalAllocatedPaise) * 100 : 50.0;

    // External Spend Analysis
    final externalSpends = ledger.where((e) => e.transactionType == TransactionType.externalSpendImpact).toList();
    final totalExternalSpendPaise = externalSpends.fold<int>(0, (sum, e) => sum + e.amountDeltaPaise.abs());
    final avgSpendPaise = externalSpends.isNotEmpty ? (totalExternalSpendPaise / externalSpends.length).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal & Portfolio Analytics'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Portfolio Health Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryAccent.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Goal Funding',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                    Icon(Icons.pie_chart_outline_rounded, color: AppTheme.primaryAccentLight, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${overallProgress.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'of ₹${(totalTargetPaise / 100).toStringAsFixed(0)} Target',
                      style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: overallProgress / 100.0,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Active Goals', '${buckets.length}', Icons.flag_outlined),
                    _buildStatItem('Spendable Pool', '₹${wallet.spendableRupees.toStringAsFixed(0)}', Icons.wallet_outlined),
                    _buildStatItem('Committed', '₹${wallet.totalAllocatedRupees.toStringAsFixed(0)}', Icons.lock_outline),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // NEED vs WANT Allocation Split
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Need vs. Want Allocation Ratio',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.balance_rounded, size: 18, color: Colors.white60),
                  ],
                ),
                const SizedBox(height: 14),
                // Stacked Ratio Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (needPercent * 10).round().clamp(1, 1000),
                          child: Container(color: AppTheme.primaryAccent),
                        ),
                        Expanded(
                          flex: (wantPercent * 10).round().clamp(1, 1000),
                          child: Container(color: AppTheme.warningAmber),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.primaryAccent, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          'NEEDS: ${needPercent.toStringAsFixed(0)}% (₹${(needAllocatedPaise / 100).toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.warningAmber, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          'WANTS: ${wantPercent.toStringAsFixed(0)}% (₹${(wantAllocatedPaise / 100).toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // External Spend Analytics Pill
          if (externalSpends.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRose.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.waterfall_chart_rounded, color: AppTheme.dangerRose, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Waterfall Protection Activity',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${externalSpends.length} bank spends absorbed • Avg ₹${(avgSpendPaise / 100).toStringAsFixed(0)} per debit',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Per-Bucket Goal Analytics List
          const Text(
            'Goal Forecasts & Target Run Rates',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...buckets.map((bucket) {
            final report = GoalAnalyticsEngine.analyze(
              bucket: bucket,
              ledgerEntries: ledger,
            );
            return _buildBucketAnalyticsCard(context, bucket, report);
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildBucketAnalyticsCard(
    BuildContext context,
    Bucket bucket,
    GoalAnalyticsReport report,
  ) {
    final hasDeadline = bucket.deadline != null;
    final isReached = report.isTargetReached;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReached
              ? AppTheme.successGreen.withOpacity(0.4)
              : (bucket.isProtected ? AppTheme.primaryAccent.withOpacity(0.3) : Colors.white10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(bucket.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bucket.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Priority ${bucket.priority} • ${bucket.type == BucketType.need ? 'Need' : 'Want'}${bucket.isProtected ? ' • 🛡️ Protected' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isReached ? AppTheme.successGreen.withOpacity(0.15) : AppTheme.primaryAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isReached ? 'COMPLETED' : '${report.percentageComplete}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isReached ? AppTheme.successGreen : AppTheme.primaryAccentLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Balance Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saved: ₹${report.currentRupees.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              Text(
                'Target: ₹${report.targetRupees.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (report.percentageComplete / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                isReached ? AppTheme.successGreen : AppTheme.primaryAccent,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Contribution Run Rates & Projections
          if (!isReached && hasDeadline && report.daysRemaining != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Required Daily', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      Text(
                        '₹${(report.requiredDailyRupees ?? 0).toStringAsFixed(0)}/day',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Required Monthly', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      Text(
                        '₹${(report.requiredMonthlyRupees ?? 0).toStringAsFixed(0)}/mo',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Days Left', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      Text(
                        '${report.daysRemaining} days',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (report.daysRemaining ?? 0) < 14 ? AppTheme.warningAmber : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (isReached) ...[
            const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 16),
                SizedBox(width: 6),
                Text(
                  'Goal 100% funded! Ready for redemption.',
                  style: TextStyle(color: AppTheme.successGreen, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
