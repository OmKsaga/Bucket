import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/models.dart';
import '../../shared/wallet_provider.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: External Spend, 2: Reallocations, 3: Income, 4: Manual Adds

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final allEntries = wallet.recentLedger;

    final filteredEntries = allEntries.where((e) {
      if (_selectedFilterIndex == 1) return e.transactionType == TransactionType.externalSpendImpact;
      if (_selectedFilterIndex == 2) return e.transactionType == TransactionType.reallocation;
      if (_selectedFilterIndex == 3) return e.transactionType == TransactionType.incomeDetected;
      if (_selectedFilterIndex == 4) {
        return e.transactionType == TransactionType.manualAdd ||
            e.transactionType == TransactionType.initialAllocation;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity & Audit Ledger'),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _LedgerFilterChip(
                  label: 'All (${allEntries.length})',
                  isSelected: _selectedFilterIndex == 0,
                  onSelected: () => setState(() => _selectedFilterIndex = 0),
                ),
                const SizedBox(width: 8),
                _LedgerFilterChip(
                  label: 'External Spend',
                  isSelected: _selectedFilterIndex == 1,
                  onSelected: () => setState(() => _selectedFilterIndex = 1),
                ),
                const SizedBox(width: 8),
                _LedgerFilterChip(
                  label: 'Reallocations',
                  isSelected: _selectedFilterIndex == 2,
                  onSelected: () => setState(() => _selectedFilterIndex = 2),
                ),
                const SizedBox(width: 8),
                _LedgerFilterChip(
                  label: 'Income',
                  isSelected: _selectedFilterIndex == 3,
                  onSelected: () => setState(() => _selectedFilterIndex = 3),
                ),
                const SizedBox(width: 8),
                _LedgerFilterChip(
                  label: 'Manual Adds',
                  isSelected: _selectedFilterIndex == 4,
                  onSelected: () => setState(() => _selectedFilterIndex = 4),
                ),
              ],
            ),
          ),

          // Ledger explanation banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_rounded, size: 16, color: AppTheme.secondaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Append-only local ledger. Financial data is stored on-device only.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ),
              ],
            ),
          ),

          // Ledger list
          Expanded(
            child: filteredEntries.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No transactions match this filter.', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return _LedgerEntryTile(entry: entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LedgerFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _LedgerFilterChip({required this.label, required this.isSelected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryAccent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _LedgerEntryTile extends ConsumerWidget {
  final LedgerEntry entry;

  const _LedgerEntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final bucketMatches = wallet.buckets.where((b) => b.id == entry.bucketId).toList();
    final bucketName = bucketMatches.isNotEmpty ? '${bucketMatches.first.icon} ${bucketMatches.first.name}' : 'Spendable Pool';

    final isPositive = entry.amountDeltaPaise > 0;
    final isReallocation = entry.transactionType == TransactionType.reallocation;
    final isExternalSpend = entry.transactionType == TransactionType.externalSpendImpact;

    Color deltaColor;
    IconData iconData;

    if (isReallocation) {
      deltaColor = AppTheme.secondaryAccent;
      iconData = Icons.swap_horiz_rounded;
    } else if (isExternalSpend) {
      deltaColor = AppTheme.dangerRose;
      iconData = Icons.arrow_outward_rounded;
    } else if (isPositive) {
      deltaColor = AppTheme.successGreen;
      iconData = Icons.arrow_downward_rounded;
    } else {
      deltaColor = AppTheme.warningAmber;
      iconData = Icons.arrow_upward_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: deltaColor.withOpacity(0.12),
          child: Icon(iconData, color: deltaColor, size: 20),
        ),
        title: Text(
          entry.note ?? entry.transactionType.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Text(bucketName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
            const SizedBox(width: 8),
            Text('• ${DateFormat('dd MMM, hh:mm a').format(entry.timestamp)}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPositive ? '+' : ''}₹${entry.deltaRupees.abs().toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: deltaColor),
            ),
            Text(
              'After: ₹${entry.balanceAfterRupees.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
