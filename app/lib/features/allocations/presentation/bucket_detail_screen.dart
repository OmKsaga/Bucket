import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/models.dart';
import '../../../domain/engines/goal_analytics_engine.dart';
import '../../shared/wallet_provider.dart';
import 'create_edit_bucket_sheet.dart';
import 'reallocate_dialog.dart';

class BucketDetailScreen extends ConsumerWidget {
  final String bucketId;

  const BucketDetailScreen({super.key, required this.bucketId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final bucketMatches = wallet.buckets.where((b) => b.id == bucketId).toList();

    if (bucketMatches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Goal Details')),
        body: const Center(child: Text('Goal not found.')),
      );
    }

    final bucket = bucketMatches.first;
    final bucketEntries = wallet.recentLedger.where((e) => e.bucketId == bucket.id).toList();
    final analytics = GoalAnalyticsEngine.analyze(bucket: bucket, ledgerEntries: bucketEntries);

    return Scaffold(
      appBar: AppBar(
        title: Text('${bucket.icon} ${bucket.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).cardColor,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => CreateEditBucketSheet(existingBucket: bucket),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRose),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Goal?'),
                  content: Text(
                    'Are you sure you want to delete ${bucket.name}? Any remaining funds (₹${(bucket.currentAllocationPaise / 100).toStringAsFixed(0)}) will be returned to your spendable balance.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRose),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ref.read(walletProvider.notifier).deleteBucket(bucket.id);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero Goal Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(child: Text(bucket.icon, style: const TextStyle(fontSize: 32))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bucket.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.getPriorityColor(bucket.priority).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    AppConstants.priorityLabels[bucket.priority] ?? 'P${bucket.priority}',
                                    style: TextStyle(
                                      color: AppTheme.getPriorityColor(bucket.priority),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    bucket.type.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (bucket.isProtected) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successGreen.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '🔒 PROTECTED',
                                      style: TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Progress Bar & Numbers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Allocated', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                          Text(
                            bucket.formattedCurrent,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryAccentLight),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Target', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                          Text(
                            bucket.formattedTarget,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: bucket.progressPercentage,
                      minHeight: 12,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        bucket.progressPercentage >= 1.0 ? AppTheme.successGreen : AppTheme.primaryAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${analytics.percentageComplete}% Saved', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Remaining: ₹${analytics.remainingRupees.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Goal Analytics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.insights_rounded, color: AppTheme.secondaryAccent, size: 20),
                      SizedBox(width: 8),
                      Text('Goal Analytics & Projections', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _AnalyticsMetric(
                          title: 'Days Left',
                          value: analytics.daysRemaining != null
                              ? (analytics.daysRemaining! < 0 ? 'Overdue' : '${analytics.daysRemaining} days')
                              : 'None',
                          color: analytics.isOverdue ? AppTheme.dangerRose : Colors.white,
                        ),
                      ),
                      Expanded(
                        child: _AnalyticsMetric(
                          title: 'Required Daily',
                          value: analytics.requiredDailyRupees != null ? '₹${analytics.requiredDailyRupees!.toStringAsFixed(0)}' : '—',
                          color: AppTheme.primaryAccentLight,
                        ),
                      ),
                      Expanded(
                        child: _AnalyticsMetric(
                          title: 'Required Monthly',
                          value: analytics.requiredMonthlyRupees != null ? '₹${analytics.requiredMonthlyRupees!.toStringAsFixed(0)}' : '—',
                          color: AppTheme.secondaryAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Add, Withdraw, Reallocate
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Funds'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
                  onPressed: () => _showAddFundsDialog(context, ref, bucket, wallet.spendableBalancePaise),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Withdraw'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkCard),
                  onPressed: () => _showWithdrawDialog(context, ref, bucket),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'Reallocate to another goal',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ReallocateDialog(sourceBucket: bucket),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Isolated Ledger History
          const Text('Goal Activity Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (bucketEntries.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No ledger entries for this goal yet.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            ),
          ] else ...[
            ...bucketEntries.map((e) {
              final isPositive = e.amountDeltaPaise > 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: isPositive ? AppTheme.successGreen : AppTheme.dangerRose,
                  ),
                  title: Text(e.note ?? e.transactionType.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(e.timestamp), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  trailing: Text(
                    '${isPositive ? '+' : ''}₹${e.deltaRupees.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isPositive ? AppTheme.successGreen : AppTheme.dangerRose,
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showAddFundsDialog(BuildContext context, WidgetRef ref, Bucket bucket, int spendablePaise) {
    int amount = 1000;
    final maxSpendableRupees = spendablePaise ~/ 100;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Add Funds to ${bucket.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Available spendable: ₹$maxSpendableRupees', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              Text('₹$amount', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [500, 1000, 2000, 5000].map((quick) {
                  return ActionChip(
                    label: Text('+₹$quick'),
                    onPressed: () => setState(() => amount = quick),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (amount <= 0 || amount > maxSpendableRupees)
                  ? null
                  : () {
                      ref.read(walletProvider.notifier).allocateToBucket(bucket.id, amount * 100);
                      Navigator.of(ctx).pop();
                    },
              child: const Text('Add Funds'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, WidgetRef ref, Bucket bucket) {
    int amount = 1000;
    final maxAllocatedRupees = bucket.currentAllocationPaise ~/ 100;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Withdraw from ${bucket.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current allocation: ₹$maxAllocatedRupees', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              Text('₹$amount', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.dangerRose)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [500, 1000, 2000].map((quick) {
                  return ActionChip(
                    label: Text('-₹$quick'),
                    onPressed: () => setState(() => amount = quick),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (amount <= 0 || amount > maxAllocatedRupees)
                  ? null
                  : () {
                      ref.read(walletProvider.notifier).deallocateFromBucket(bucket.id, amount * 100);
                      Navigator.of(ctx).pop();
                    },
              child: const Text('Withdraw'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _AnalyticsMetric({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
