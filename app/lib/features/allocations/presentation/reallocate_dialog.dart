import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/models.dart';
import '../../shared/wallet_provider.dart';

class ReallocateDialog extends ConsumerStatefulWidget {
  final Bucket sourceBucket;

  const ReallocateDialog({super.key, required this.sourceBucket});

  @override
  ConsumerState<ReallocateDialog> createState() => _ReallocateDialogState();
}

class _ReallocateDialogState extends ConsumerState<ReallocateDialog> {
  Bucket? _targetBucket;
  int _amountRupees = 1000;

  @override
  void initState() {
    super.initState();
    final allBuckets = ref.read(walletProvider).buckets;
    final otherBuckets = allBuckets.where((b) => b.id != widget.sourceBucket.id).toList();
    if (otherBuckets.isNotEmpty) {
      _targetBucket = otherBuckets.first;
    }
    final sourceMax = widget.sourceBucket.currentAllocationPaise ~/ 100;
    if (_amountRupees > sourceMax) {
      _amountRupees = sourceMax;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final otherBuckets = wallet.buckets.where((b) => b.id != widget.sourceBucket.id).toList();
    final sourceMaxRupees = widget.sourceBucket.currentAllocationPaise ~/ 100;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Virtual Reallocation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Move committed funds between virtual goals. No bank transfer occurs.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Visual Transfer Diagram
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Source
                  Expanded(
                    child: Column(
                      children: [
                        Text(widget.sourceBucket.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(
                          widget.sourceBucket.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '₹${(widget.sourceBucket.currentAllocationPaise / 100).toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.dangerRose),
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryAccent, size: 28),
                  ),

                  // Target
                  Expanded(
                    child: _targetBucket == null
                        ? const Center(child: Text('No goals'))
                        : Column(
                            children: [
                              Text(_targetBucket!.icon, style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 4),
                              Text(
                                _targetBucket!.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '₹${(_targetBucket!.currentAllocationPaise / 100).toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.successGreen),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Target selector dropdown
            const Text('Destination Goal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _targetBucket?.id,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: otherBuckets
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text('${b.icon} ${b.name} (P${b.priority})'),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _targetBucket = otherBuckets.firstWhere((b) => b.id == val);
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Amount Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount to Move', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '₹$_amountRupees',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryAccent),
                ),
              ],
            ),
            if (sourceMaxRupees > 0) ...[
              Slider(
                value: _amountRupees.toDouble().clamp(0, sourceMaxRupees.toDouble()),
                min: 0,
                max: sourceMaxRupees.toDouble(),
                divisions: sourceMaxRupees > 0 ? (sourceMaxRupees ~/ 500).clamp(1, 100) : 1,
                activeColor: AppTheme.primaryAccent,
                onChanged: (val) => setState(() => _amountRupees = val.round()),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Source bucket has ₹0 allocation.', style: TextStyle(color: AppTheme.dangerRose, fontSize: 12)),
              ),
            ],
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_amountRupees <= 0 || _targetBucket == null || _amountRupees > sourceMaxRupees)
                        ? null
                        : () {
                            ref.read(walletProvider.notifier).reallocateBetweenBuckets(
                                  widget.sourceBucket.id,
                                  _targetBucket!.id,
                                  _amountRupees * 100,
                                );
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Reallocated ₹$_amountRupees from ${widget.sourceBucket.name} to ${_targetBucket!.name}'),
                                backgroundColor: AppTheme.primaryAccent,
                              ),
                            );
                          },
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
