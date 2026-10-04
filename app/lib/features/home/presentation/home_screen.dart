import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/models.dart';
import '../../auth/services/auth_service.dart';
import '../../shared/wallet_provider.dart';
import '../../payments/presentation/payment_sheet.dart';
import '../../allocations/presentation/bucket_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback onNavigateToBuckets;
  final VoidCallback onNavigateToLedger;

  const HomeScreen({
    super.key,
    required this.onNavigateToBuckets,
    required this.onNavigateToLedger,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final isDeficit = wallet.hasDeficit;
    final spendableColor = isDeficit
        ? AppTheme.dangerRose
        : (wallet.spendableRupees > 0 ? AppTheme.successGreen : AppTheme.warningAmber);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.savings_rounded, color: AppTheme.primaryAccent, size: 26),
            const SizedBox(width: 8),
            Text(AppConstants.appName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Bank Balance',
            onPressed: () {
              ref.read(walletProvider.notifier).syncWithProvider();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Balances synchronized.')),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final auth = ref.watch(authProvider);
              return IconButton(
                icon: Stack(
                  children: [
                    Icon(
                      auth.isAuthenticated ? Icons.account_circle : Icons.account_circle_outlined,
                      color: auth.isAuthenticated ? AppTheme.primaryAccent : Colors.white70,
                    ),
                    if (auth.isAuthenticated)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: auth.isAuthenticated ? 'Account (${auth.email})' : 'Sign In',
                onPressed: () => context.push('/auth'),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Hero 3-in-1 Balance Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF334155), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryAccent.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, color: AppTheme.textMuted, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${wallet.account.bankName} (${wallet.account.accountNumberMask})',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Virtual Ledger Active',
                        style: TextStyle(color: AppTheme.primaryAccentLight, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Spendable Balance Highlight
                const Text('SPENDABLE / UNALLOCATED', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(
                  '₹${wallet.spendableRupees.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: spendableColor),
                ),
                if (isDeficit) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '⚠️ Virtual allocations exceed real bank balance.',
                    style: TextStyle(color: AppTheme.dangerRose, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 12),

                // Split metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Bank Balance', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${wallet.totalBankRupees.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Committed to Goals', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${wallet.totalAllocatedRupees.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryAccentLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text('Scan & Pay'),
                  onPressed: () => context.push('/qr-scanner'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Money'),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Theme.of(context).cardColor,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (_) => const PaymentSheet(
                        title: 'Send Money',
                        defaultRecipient: 'friend.alex@upi',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Goals Spotlight Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Priority Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: onNavigateToBuckets,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Goals Carousel
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: wallet.buckets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final b = wallet.buckets[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BucketDetailScreen(bucketId: b.id)),
                    );
                  },
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(b.icon, style: const TextStyle(fontSize: 26)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.getPriorityColor(b.priority).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'P${b.priority}',
                                style: TextStyle(
                                  color: AppTheme.getPriorityColor(b.priority),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                            Text(
                              '₹${(b.currentAllocationPaise / 100).toStringAsFixed(0)}',
                              style: const TextStyle(color: AppTheme.primaryAccentLight, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: b.progressPercentage,
                                minHeight: 4,
                                backgroundColor: Colors.grey.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  b.progressPercentage >= 1.0 ? AppTheme.successGreen : AppTheme.primaryAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Recent Activity Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Ledger Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: onNavigateToLedger,
                child: const Text('Full Audit'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (wallet.recentLedger.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No transactions yet.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            ),
          ] else ...[
            ...wallet.recentLedger.take(4).map((entry) {
              final isPositive = entry.amountDeltaPaise > 0;
              final isExternal = entry.transactionType == TransactionType.externalSpendImpact;
              final isRealloc = entry.transactionType == TransactionType.reallocation;

              Color color = isPositive ? AppTheme.successGreen : (isExternal ? AppTheme.dangerRose : AppTheme.secondaryAccent);
              IconData icon = isRealloc
                  ? Icons.swap_horiz_rounded
                  : (isPositive ? Icons.arrow_downward_rounded : Icons.arrow_outward_rounded);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  title: Text(entry.note ?? entry.transactionType.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(DateFormat('dd MMM, hh:mm a').format(entry.timestamp), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: Text(
                    '${isPositive ? '+' : ''}₹${entry.deltaRupees.abs().toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
