import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/models.dart';
import '../../shared/wallet_provider.dart';
import 'bucket_detail_screen.dart';
import 'create_edit_bucket_sheet.dart';
import 'reallocate_dialog.dart';

class BucketsScreen extends ConsumerStatefulWidget {
  const BucketsScreen({super.key});

  @override
  ConsumerState<BucketsScreen> createState() => _BucketsScreenState();
}

class _BucketsScreenState extends ConsumerState<BucketsScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Needs, 2: Wants, 3: Completed
  bool _sortByPriority = true;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final allBuckets = wallet.buckets;

    // Apply Filter
    List<Bucket> filteredBuckets = allBuckets.where((b) {
      if (_selectedFilterIndex == 1) return b.type == BucketType.need && !b.isCompleted;
      if (_selectedFilterIndex == 2) return b.type == BucketType.want && !b.isCompleted;
      if (_selectedFilterIndex == 3) return b.isCompleted;
      return true;
    }).toList();

    // Apply Sort (Priority ASC 1->5 or DESC)
    if (_sortByPriority) {
      filteredBuckets.sort((a, b) => a.priority.compareTo(b.priority));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Goal Buckets'),
        actions: [
          IconButton(
            icon: Icon(_sortByPriority ? Icons.sort_rounded : Icons.calendar_month_outlined),
            tooltip: 'Toggle Sort Order',
            onPressed: () => setState(() => _sortByPriority = !_sortByPriority),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All (${allBuckets.length})',
                  isSelected: _selectedFilterIndex == 0,
                  onSelected: () => setState(() => _selectedFilterIndex = 0),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Needs (${allBuckets.where((b) => b.type == BucketType.need).length})',
                  isSelected: _selectedFilterIndex == 1,
                  onSelected: () => setState(() => _selectedFilterIndex = 1),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Wants (${allBuckets.where((b) => b.type == BucketType.want).length})',
                  isSelected: _selectedFilterIndex == 2,
                  onSelected: () => setState(() => _selectedFilterIndex = 2),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Completed (${allBuckets.where((b) => b.isCompleted).length})',
                  isSelected: _selectedFilterIndex == 3,
                  onSelected: () => setState(() => _selectedFilterIndex = 3),
                ),
              ],
            ),
          ),

          // Priority order explanation banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.primaryAccentLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sorted by deduction priority: P1 drains first during external spend.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ),
              ],
            ),
          ),

          // Bucket List
          Expanded(
            child: filteredBuckets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_rounded, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        const Text('No goals in this section', style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create Goal'),
                          onPressed: () => _openCreateSheet(context),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredBuckets.length,
                    itemBuilder: (context, index) {
                      final bucket = filteredBuckets[index];
                      return _BucketCard(bucket: bucket);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openCreateSheet(context),
      ),
    );
  }

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const CreateEditBucketSheet(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({required this.label, required this.isSelected, required this.onSelected});

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

class _BucketCard extends ConsumerWidget {
  final Bucket bucket;

  const _BucketCard({required this.bucket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = AppTheme.getPriorityColor(bucket.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BucketDetailScreen(bucketId: bucket.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(bucket.icon, style: const TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                bucket.name,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (bucket.isProtected)
                              const Tooltip(
                                message: 'Protected against external spending auto-deduction',
                                child: Icon(Icons.lock_rounded, size: 16, color: AppTheme.successGreen),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'P${bucket.priority}',
                                style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• ${bucket.type.name.toUpperCase()}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            if (bucket.deadline != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• Due ${DateFormat('dd MMM').format(bucket.deadline!)}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Progress row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bucket.formattedCurrent,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryAccentLight),
                  ),
                  Text(
                    'of ${bucket.formattedTarget}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: bucket.progressPercentage,
                  minHeight: 8,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    bucket.progressPercentage >= 1.0 ? AppTheme.successGreen : AppTheme.primaryAccent,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Quick action footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(bucket.progressPercentage * 100).toStringAsFixed(0)}% completed',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text('Reallocate', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => ReallocateDialog(sourceBucket: bucket),
                          );
                        },
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
