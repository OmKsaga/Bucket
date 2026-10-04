import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/wallet_provider.dart';

class SyncSimulatorScreen extends ConsumerStatefulWidget {
  const SyncSimulatorScreen({super.key});

  @override
  ConsumerState<SyncSimulatorScreen> createState() => _SyncSimulatorScreenState();
}

class _SyncSimulatorScreenState extends ConsumerState<SyncSimulatorScreen> {
  final _balanceController = TextEditingController();
  int _targetBalanceRupees = 24000;

  @override
  void initState() {
    super.initState();
    final currentRupees = ref.read(walletProvider).totalBankRupees.toInt();
    _targetBalanceRupees = currentRupees > 6000 ? currentRupees - 6000 : currentRupees;
    _balanceController.text = _targetBalanceRupees.toString();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final currentBankRupees = wallet.totalBankRupees.toInt();
    final diffRupees = _targetBalanceRupees - currentBankRupees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Sync Simulator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Current status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Current Known Bank Balance', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    wallet.account.formattedBalance,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryAccentLight),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last synced: ${wallet.account.lastSyncedAt.hour}:${wallet.account.lastSyncedAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Simulation Control Section
          const Text('Simulate External Bank Activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Change your bank balance to test how the local allocation engine detects differences and automatically adjusts virtual buckets.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),

          // Quick Preset Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.shopping_bag_outlined, size: 16, color: AppTheme.dangerRose),
                label: const Text('-₹6,000 (Grocery / Mall)'),
                onPressed: () {
                  final newBal = (currentBankRupees - 6000).clamp(0, 500000);
                  setState(() {
                    _targetBalanceRupees = newBal;
                    _balanceController.text = newBal.toString();
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.local_fire_department_outlined, size: 16, color: AppTheme.warningAmber),
                label: const Text('-₹10,000 (Multi-goal overflow)'),
                onPressed: () {
                  final newBal = (currentBankRupees - 10000).clamp(0, 500000);
                  setState(() {
                    _targetBalanceRupees = newBal;
                    _balanceController.text = newBal.toString();
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.account_balance_outlined, size: 16, color: AppTheme.successGreen),
                label: const Text('+₹15,000 (Salary / Income)'),
                onPressed: () {
                  final newBal = (currentBankRupees + 15000).clamp(0, 500000);
                  setState(() {
                    _targetBalanceRupees = newBal;
                    _balanceController.text = newBal.toString();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Custom Input
          TextField(
            controller: _balanceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Simulated New Bank Balance (₹)',
              prefixText: '₹ ',
              suffixText: diffRupees != 0
                  ? '${diffRupees > 0 ? '+' : ''}₹${diffRupees.abs()} (${diffRupees > 0 ? 'Income' : 'Spend'})'
                  : 'No change',
              suffixStyle: TextStyle(
                color: diffRupees < 0
                    ? AppTheme.dangerRose
                    : diffRupees > 0
                        ? AppTheme.successGreen
                        : AppTheme.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val) ?? currentBankRupees;
              setState(() => _targetBalanceRupees = parsed);
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Execute Sync & Reconcile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: () {
              ref.read(walletProvider.notifier).simulateBalanceSync(_targetBalanceRupees * 100);
            },
          ),
          const SizedBox(height: 24),

          // Result Inspection Area
          if (wallet.lastWaterfallResult != null && wallet.lastWaterfallResult!.affectedBuckets.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.warningAmber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'External spending detected: -₹${wallet.lastWaterfallResult!.totalSpendRupees.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.warningAmber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Waterfall algorithm adjusted the following goal buckets:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  ...wallet.lastWaterfallResult!.affectedBuckets.map((impact) {
                    final prevRupees = impact.originalBucket.currentAllocationPaise ~/ 100;
                    final newRupees = impact.updatedBucket.currentAllocationPaise ~/ 100;
                    final deducted = impact.deductedAmountPaise ~/ 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${impact.originalBucket.icon} ${impact.originalBucket.name} (P${impact.originalBucket.priority})'),
                          Text(
                            '₹$prevRupees → ₹$newRupees (-₹$deducted)',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dangerRose),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ] else if (wallet.lastSyncMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.successGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(wallet.lastSyncMessage!, style: const TextStyle(color: AppTheme.successGreen)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
