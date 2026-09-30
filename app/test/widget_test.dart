import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/main.dart';
import 'package:bucket_app/core/constants/app_constants.dart';

void main() {
  testWidgets('BucketApp smoke test displays app branding', (WidgetTester tester) async {
    await tester.pumpWidget(const BucketApp());

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.appTagline), findsOneWidget);
  });
}
