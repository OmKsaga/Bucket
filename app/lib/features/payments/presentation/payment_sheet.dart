import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/services/payment_warning_service.dart';
import '../../shared/wallet_provider.dart';

class PaymentSheet extends ConsumerStatefulWidget {
  final String title;
  final String defaultRecipient;

  const PaymentSheet({
    super.key,
    required this.title,
    required this.defaultRecipient,
  });

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final _amountController = TextEditingController();
  final _recipientController = TextEditingController();
  int _amountRupees = 0;

  @override
  void initState() {
    super.initState();
    _recipientController.text = widget.defaultRecipient;
    _amountController.addListener(() {
      final parsed = int.tryParse(_amountController.text.trim()) ?? 0;
      if (parsed != _amountRupees) {
        setState(() {
          _amountRupees = parsed;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final int amountPaise = _amountRupees * 100;

    PaymentWarningEvaluation? evaluation;
    if (_amountRupees > 0) {
      evaluation = PaymentWarningService.evaluate(
        amountPaise: amountPaise,
        spendableBalancePaise: wallet.spendableBalancePaise,
        activeBuckets: wallet.buckets,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _recipientController,
            decoration: const InputDecoration(
              labelText: 'Pay To (UPI ID / Merchant)',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryAccent),
            ),
          ),
          const SizedBox(height: 16),

          // Live Impact Warning Assessment using PaymentWarningService
          if (evaluation != null) ...[
            if (evaluation.status == PaymentSafetyStatus.safe) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.successGreen.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        evaluation.description,
                        style: const TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (evaluation.status == PaymentSafetyStatus.criticalDeficit ? AppTheme.dangerRose : AppTheme.warningAmber).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (evaluation.status == PaymentSafetyStatus.criticalDeficit ? AppTheme.dangerRose : AppTheme.warningAmber).withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: evaluation.status == PaymentSafetyStatus.criticalDeficit ? AppTheme.dangerRose : AppTheme.warningAmber,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          evaluation.title,
                          style: TextStyle(
                            color: evaluation.status == PaymentSafetyStatus.criticalDeficit ? AppTheme.dangerRose : AppTheme.warningAmber,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      evaluation.description,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    if (evaluation.predictedImpactedBuckets.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...evaluation.predictedImpactedBuckets.map((impact) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${impact.bucket.icon} ${impact.bucket.name} (P${impact.bucket.priority})',
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                              Text(
                                '-₹${impact.predictedDeductionRupees.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.dangerRose),
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
            const SizedBox(height: 20),
          ],

          ElevatedButton(
            onPressed: _amountRupees <= 0
                ? null
                : () {
                    ref.read(walletProvider.notifier).simulatePayment(
                          amountPaise: amountPaise,
                          recipient: _recipientController.text.trim(),
                        );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Paid ₹$_amountRupees to ${_recipientController.text.trim()}'),
                        backgroundColor: (evaluation?.exceedsSpendable ?? false) ? AppTheme.warningAmber : AppTheme.successGreen,
                      ),
                    );
                  },
            child: Text(
              _amountRupees <= 0 ? 'Enter Amount' : 'Pay ₹$_amountRupees',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
