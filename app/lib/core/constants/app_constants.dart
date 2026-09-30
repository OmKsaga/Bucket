/// Core application constants for the Bucket app.
class AppConstants {
  static const String appName = 'Bucket';
  static const String appTagline = 'Give every rupee a purpose.';

  // Currency constants
  static const String currencySymbol = '₹';
  static const int paisePerRupee = 100;

  // Priority labels
  static const Map<int, String> priorityLabels = {
    1: '1 - First to sacrifice',
    2: '2 - Low priority',
    3: '3 - Medium priority',
    4: '4 - High priority',
    5: '5 - Essential / Last to sacrifice',
  };
}
