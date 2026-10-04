import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../../auth/services/auth_service.dart';
import '../../shared/wallet_provider.dart';

class PaymentInitiationResult {
  final String providerRef;
  final String payeeVpa;
  final String payeeName;
  final int amountPaise;
  final String upiIntentUrl;
  final bool isBackendSynced;

  PaymentInitiationResult({
    required this.providerRef,
    required this.payeeVpa,
    required this.payeeName,
    required this.amountPaise,
    required this.upiIntentUrl,
    required this.isBackendSynced,
  });
}

class UpiPaymentService {
  final ApiClient apiClient;

  UpiPaymentService({required this.apiClient});

  static String buildUpiUri({
    required String payeeVpa,
    required String payeeName,
    required int amountPaise,
    required String providerRef,
    String note = 'Bucket UPI Payment',
  }) {
    final amountRupees = (amountPaise / 100).toStringAsFixed(2);
    final query = [
      'pa=${Uri.encodeComponent(payeeVpa)}',
      'pn=${Uri.encodeComponent(payeeName)}',
      'am=$amountRupees',
      'cu=INR',
      'tn=${Uri.encodeComponent(note)}',
      'tr=$providerRef',
    ].join('&');

    return 'upi://pay?$query';
  }

  Future<PaymentInitiationResult> initiatePayment({
    required String payeeVpa,
    required String payeeName,
    required int amountPaise,
    String? note,
  }) async {
    try {
      if (apiClient.isAuthenticated) {
        final resp = await apiClient.initiatePayment(
          payeeVpa: payeeVpa,
          payeeName: payeeName,
          amountPaise: amountPaise,
          note: note,
        );
        return PaymentInitiationResult(
          providerRef: resp['provider_ref'] as String,
          payeeVpa: resp['payee_vpa'] as String,
          payeeName: resp['payee_name'] as String,
          amountPaise: (resp['amount_paise'] as num).toInt(),
          upiIntentUrl: resp['upi_intent_url'] as String,
          isBackendSynced: true,
        );
      }
    } catch (_) {
      // Fallback to local generation if backend is unavailable or offline
    }

    final localRef = 'BCK${DateTime.now().millisecondsSinceEpoch}';
    final url = buildUpiUri(
      payeeVpa: payeeVpa,
      payeeName: payeeName,
      amountPaise: amountPaise,
      providerRef: localRef,
      note: note ?? 'Bucket Payment',
    );

    return PaymentInitiationResult(
      providerRef: localRef,
      payeeVpa: payeeVpa,
      payeeName: payeeName,
      amountPaise: amountPaise,
      upiIntentUrl: url,
      isBackendSynced: false,
    );
  }

  void schedulePostPaymentSync({
    required WidgetRef ref,
    Duration delay = const Duration(seconds: 30),
  }) {
    // Triggers reconciliation after payment settlement delay
    Timer(delay, () {
      try {
        ref.read(walletProvider.notifier).syncWithProvider();
      } catch (_) {}
    });
  }
}

final upiPaymentServiceProvider = Provider<UpiPaymentService>((ref) {
  final client = ref.watch(apiClientProvider);
  return UpiPaymentService(apiClient: client);
});
