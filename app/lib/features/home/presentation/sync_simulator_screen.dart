import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/services/reconciliation_service.dart';
import '../../shared/wallet_provider.dart';

class SyncSimulatorScreen extends ConsumerStatefulWidget {
  const SyncSimulatorScreen({super.key});

  @override
  ConsumerState<SyncSimulatorScreen> createState() => _SyncSimulatorScreenState();
}

class _SyncSimulatorScreenState extends ConsumerState<SyncSimulatorScreen> {
  final _balanceController = TextEditingController();
  int _targetBalanceRupees = 24000;
  bool _isSyncing = false;
  String _syncStep = '';
  SyncOutcome? _lastOutcome;

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

  Future<void> _runAnimatedSync({bool force = false}) async {
    setState(() {
      _isSyncing = true;
      _syncStep = 'Contacting bank / PSP sandbox...';
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _syncStep = 'Comparing real balance with local ledger...');

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _syncStep = 'Checking transactions for external spending...');

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _syncStep = 'Running waterfall deduction across goals...');

    final outcome = await ref.read(walletProvider.notifier).syncWithProvider(force: force);

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _syncStep = '';
      _lastOutcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final currentBankRupees = wallet.totalBankRupees.toInt();
    final diffRupees = _targetBalanceRupees - currentBankRupees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Sync & Reconciliation'),
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
                    'Last synced: ${DateFormat('dd MMM yyyy, hh:mm:ss a').format(wallet.account.lastSyncedAt)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Live Sync Progress Animation
          if (_isSyncing) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(color: AppTheme.primaryAccent),
                  const SizedBox(height: 14),
                  Text(
                    _syncStep,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryAccentLight, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Simulation Control Section
          const Text('Simulate Real Bank Sync Activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Queue an external transaction in the bank provider, then run synchronization to trigger the Reconciliation Service.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),

          // Preset Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.shopping_bag_outlined, size: 16, color: AppTheme.dangerRose),
                label: const Text('-₹6,000 External Spend'),
                onPressed: () {
                  final newBal = (currentBankRupees - 6000).clamp(0, 500000);
                  ref.read(walletProvider.notifier).mockSyncProvider.setBankBalance(newBal * 100);
                  setState(() {
                    _targetBalanceRupees = newBal;
                    _balanceController.text = newBal.toString();
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.local_fire_department_outlined, size: 16, color: AppTheme.warningAmber),
                label: const Text('-₹10,000 Multi-goal Overflow'),
                onPressed: () {
                  final newBal = (currentBankRupees - 10000).clamp(0, 500000);
                  ref.read(walletProvider.notifier).mockSyncProvider.setBankBalance(newBal * 100);
                  setState(() {
                    _targetBalanceRupees = newBal;
                    _balanceController.text = newBal.toString();
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.account_balance_outlined, size: 16, color: AppTheme.successGreen),
                label: const Text('+₹15,000 Salary Credit'),
                onPressed: () {
                  final newBal = (currentBankRupees + 15000).clamp(0, 500000);
                  ref.read(walletProvider.notifier).mockSyncProvider.setBankBalance(newBal * 100);
                  setState(() {
                    _targetBalanceRupees = newBal;
                    _balanceController.text = newBal.toString();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Input
          TextField(
            controller: _balanceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Simulated Target Bank Balance (₹)',
              prefixText: '₹ ',
              suffixText: diffRupees != 0
                  ? '${diffRupees > 0 ? '+' : ''}₹${diffRupees.abs()} (${diffRupees > 0 ? 'Credit' : 'Debit'})'
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
              ref.read(walletProvider.notifier).mockSyncProvider.setBankBalance(parsed * 100);
            },
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Run Reconciliation Pipeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _isSyncing ? null : () => _runAnimatedSync(force: true),
          ),
          const SizedBox(height: 24),

          // Detailed Outcome Card
          if (_lastOutcome != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _lastOutcome!.classification == SyncClassification.externalSpend
                    ? AppTheme.warningAmber.withOpacity(0.1)
                    : AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _lastOutcome!.classification == SyncClassification.externalSpend
                      ? AppTheme.warningAmber.withOpacity(0.4)
                      : AppTheme.successGreen.withOpacity(0.4),
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
                          Icon(
                            _lastOutcome!.classification == SyncClassification.externalSpend
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            color: _lastOutcome!.classification == SyncClassification.externalSpend
                                ? AppTheme.warningAmber
                                : AppTheme.successGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _lastOutcome!.classification == SyncClassification.externalSpend
                                ? 'External Spend Detected'
                                : 'Sync Complete',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _lastOutcome!.classification == SyncClassification.externalSpend
                                  ? AppTheme.warningAmber
                                  : AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Hash: ${_lastOutcome!.sessionHash.substring(0, 8)}...',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_lastOutcome!.message, style: const TextStyle(fontSize: 13)),

                  if (_lastOutcome!.affectedBuckets.isNotEmpty) ...[
                    const Divider(height: 20),
                    const Text('Waterfall Deductions Committed to Ledger:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ..._lastOutcome!.affectedBuckets.map((impact) {
                      final prev = impact.originalBucket.currentAllocationPaise ~/ 100;
                      final curr = impact.updatedBucket.currentAllocationPaise ~/ 100;
                      final deducted = impact.deductedAmountPaise ~/ 100;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${impact.originalBucket.icon} ${impact.originalBucket.name} (P${impact.originalBucket.priority})'),
                            Text(
                              '₹$prev → ₹$curr (-₹$deducted)',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dangerRose),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
