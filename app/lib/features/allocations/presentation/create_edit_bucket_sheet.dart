import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/models.dart';
import '../../shared/wallet_provider.dart';

class CreateEditBucketSheet extends ConsumerStatefulWidget {
  final Bucket? existingBucket;

  const CreateEditBucketSheet({super.key, this.existingBucket});

  @override
  ConsumerState<CreateEditBucketSheet> createState() => _CreateEditBucketSheetState();
}

class _CreateEditBucketSheetState extends ConsumerState<CreateEditBucketSheet> {
  static const _availableIcons = ['💻', '🏠', '👟', '🎮', '🛵', '✈️', '🛡️', '💍', '📚', '🚗', '🎸', '📱'];
  static const _categories = ['Tech', 'Housing', 'Shopping', 'Gaming', 'Transport', 'Travel', 'Savings', 'Education'];

  late TextEditingController _nameController;
  late TextEditingController _targetController;
  late TextEditingController _initialAllocController;
  late TextEditingController _notesController;

  late String _selectedIcon;
  late String _selectedCategory;
  late BucketType _selectedType;
  late int _selectedPriority;
  late bool _isProtected;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBucket;
    _nameController = TextEditingController(text: b?.name ?? '');
    _targetController = TextEditingController(text: b != null ? (b.targetAmountPaise ~/ 100).toString() : '');
    _initialAllocController = TextEditingController(text: b != null ? (b.currentAllocationPaise ~/ 100).toString() : '0');
    _notesController = TextEditingController(text: b?.notes ?? '');

    _selectedIcon = b?.icon ?? '🎯';
    _selectedCategory = b?.category ?? _categories.first;
    _selectedType = b?.type ?? BucketType.want;
    _selectedPriority = b?.priority ?? 3;
    _isProtected = b?.isProtected ?? false;
    _deadline = b?.deadline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialAllocController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingBucket != null;
    final wallet = ref.watch(walletProvider);
    final maxInitialRupees = wallet.spendableRupees;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'Edit Goal' : 'Create Virtual Goal Bucket',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                // Icon Picker
                const Text('Choose Icon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableIcons.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final icon = _availableIcons[index];
                      final isSelected = icon == _selectedIcon;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = icon),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryAccent.withOpacity(0.3) : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryAccent : Colors.grey.withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Name',
                    hintText: 'e.g. MacBook M4, PS5, Emergency Fund',
                  ),
                ),
                const SizedBox(height: 14),

                // Target Amount
                TextField(
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target Amount (₹)',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 14),

                // Initial Allocation (Only when creating)
                if (!isEditing) ...[
                  TextField(
                    controller: _initialAllocController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Initial Allocation (₹)',
                      prefixText: '₹ ',
                      helperText: 'Available spendable balance: ₹${maxInitialRupees.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Category dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 16),

                // Need vs Want
                const Text('Goal Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                SegmentedButton<BucketType>(
                  segments: const [
                    ButtonSegment(
                      value: BucketType.want,
                      label: Text('WANT'),
                      icon: Icon(Icons.star_border),
                    ),
                    ButtonSegment(
                      value: BucketType.need,
                      label: Text('NEED'),
                      icon: Icon(Icons.shield_outlined),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (set) {
                    setState(() {
                      _selectedType = set.first;
                      // Smart defaults
                      if (_selectedType == BucketType.need && _selectedPriority < 4) {
                        _selectedPriority = 4;
                      } else if (_selectedType == BucketType.want && _selectedPriority > 3) {
                        _selectedPriority = 2;
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Priority Slider (1 to 5)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Priority Level', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      AppConstants.priorityLabels[_selectedPriority] ?? 'P$_selectedPriority',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getPriorityColor(_selectedPriority),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _selectedPriority.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: AppTheme.getPriorityColor(_selectedPriority),
                  onChanged: (val) => setState(() => _selectedPriority = val.round()),
                ),
                Text(
                  _selectedPriority == 1
                      ? 'Priority 1: First to be drained if external spending occurs.'
                      : _selectedPriority == 5
                          ? 'Priority 5: Essential goal. Only drained after all lower priorities.'
                          : 'Cascade order: Priority $_selectedPriority.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),

                // Protected switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Protect Against Auto-Deductions', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                    'When enabled, money in this bucket is strictly locked and will never be deducted during external spending.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  value: _isProtected,
                  activeColor: AppTheme.successGreen,
                  onChanged: (val) => setState(() => _isProtected = val),
                ),
                const SizedBox(height: 12),

                // Deadline Picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined, color: AppTheme.primaryAccent),
                  title: const Text('Target Deadline (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _deadline != null ? DateFormat('dd MMM yyyy').format(_deadline!) : 'No deadline set',
                    style: TextStyle(color: _deadline != null ? Colors.white : AppTheme.textMuted),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deadline ?? DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                      );
                      if (picked != null) setState(() => _deadline = picked);
                    },
                    child: Text(_deadline != null ? 'Change' : 'Set Date'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () {
              final name = _nameController.text.trim();
              final targetRupees = int.tryParse(_targetController.text.trim()) ?? 0;
              final initialRupees = int.tryParse(_initialAllocController.text.trim()) ?? 0;

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a goal name')));
                return;
              }
              if (targetRupees <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target amount must be > 0')));
                return;
              }

              final now = DateTime.now();

              if (isEditing) {
                final updated = widget.existingBucket!.copyWith(
                  name: name,
                  icon: _selectedIcon,
                  targetAmountPaise: targetRupees * 100,
                  category: _selectedCategory,
                  type: _selectedType,
                  priority: _selectedPriority,
                  isProtected: _isProtected,
                  deadline: _deadline,
                  notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                  updatedAt: now,
                );
                ref.read(walletProvider.notifier).updateBucket(updated);
              } else {
                final newBucket = Bucket(
                  id: 'b_${const Uuid().v4().substring(0, 8)}',
                  name: name,
                  icon: _selectedIcon,
                  targetAmountPaise: targetRupees * 100,
                  currentAllocationPaise: 0,
                  category: _selectedCategory,
                  type: _selectedType,
                  priority: _selectedPriority,
                  isProtected: _isProtected,
                  deadline: _deadline,
                  notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                );
                ref.read(walletProvider.notifier).createBucket(
                      newBucket,
                      initialAllocationPaise: initialRupees * 100,
                    );
              }

              Navigator.of(context).pop();
            },
            child: Text(
              isEditing ? 'Save Changes' : 'Create Goal Bucket',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
