import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bucket_app/main.dart';
import 'package:bucket_app/core/constants/app_constants.dart';

void main() {
  testWidgets('BucketApp boots and renders navigation tabs and brand title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BucketApp(),
      ),
    );

    // Initial pump and frame
    await tester.pumpAndSettle();

    // Verify App Name in AppBar
    expect(find.text(AppConstants.appName), findsOneWidget);

    // Verify 4 Navigation Tabs
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Simulator'), findsOneWidget);

    // Verify Action buttons
    expect(find.text('Scan & Pay'), findsOneWidget);
    expect(find.text('Send Money'), findsOneWidget);
  });
}
