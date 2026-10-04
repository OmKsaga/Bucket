import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/core/networking/api_client.dart';
import 'package:bucket_app/features/payments/services/upi_payment_service.dart';

void main() {
  group('UpiPaymentService Unit Tests', () {
    test('buildUpiUri constructs compliant NPCI URI with 2-decimal rupee precision', () {
      final uriStr = UpiPaymentService.buildUpiUri(
        payeeVpa: 'merchant@icici',
        payeeName: 'Blue Tokai Coffee',
        amountPaise: 28000, // Rs 280.00
        providerRef: 'BCK12345678',
        note: 'Cold Brew & Croissant',
      );

      expect(uriStr.startsWith('upi://pay?'), isTrue);
      final uri = Uri.parse(uriStr);
      expect(uri.queryParameters['pa'], equals('merchant@icici'));
      expect(uri.queryParameters['pn'], equals('Blue Tokai Coffee'));
      expect(uri.queryParameters['am'], equals('280.00'));
      expect(uri.queryParameters['cu'], equals('INR'));
      expect(uri.queryParameters['tn'], equals('Cold Brew & Croissant'));
      expect(uri.queryParameters['tr'], equals('BCK12345678'));
    });

    test('initiatePayment falls back gracefully when unauthenticated or offline', () async {
      final client = ApiClient(baseUrl: 'http://localhost:8000/api/v1');
      final service = UpiPaymentService(apiClient: client);

      final result = await service.initiatePayment(
        payeeVpa: 'grocery@axisbank',
        payeeName: 'Fresh Mart',
        amountPaise: 150050, // Rs 1500.50
        note: 'Weekly essentials',
      );

      expect(result.isBackendSynced, isFalse);
      expect(result.providerRef.startsWith('BCK'), isTrue);
      expect(result.amountPaise, equals(150050));
      expect(result.upiIntentUrl.contains('pa=grocery%40axisbank'), isTrue);
      expect(result.upiIntentUrl.contains('am=1500.50'), isTrue);
    });
  });
}
