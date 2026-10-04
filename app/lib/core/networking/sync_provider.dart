enum ExternalTransactionType {
  debit,
  credit,
  refund,
}

/// Represents an external transaction retrieved from the bank / PSP statement.
class ExternalTransaction {
  final String id;
  final int amountPaise;
  final ExternalTransactionType type;
  final String description;
  final String? merchantName;
  final String? referenceId;
  final DateTime timestamp;

  const ExternalTransaction({
    required this.id,
    required this.amountPaise,
    required this.type,
    required this.description,
    this.merchantName,
    this.referenceId,
    required this.timestamp,
  });

  double get amountRupees => amountPaise / 100.0;
}

/// Response returned by a BalanceSyncProvider.
class BalanceSyncResult {
  final int currentBalancePaise;
  final DateTime timestamp;
  final List<ExternalTransaction> transactions;
  final Map<String, dynamic>? rawMetadata;

  const BalanceSyncResult({
    required this.currentBalancePaise,
    required this.timestamp,
    this.transactions = const [],
    this.rawMetadata,
  });

  double get currentBalanceRupees => currentBalancePaise / 100.0;
}

enum ProviderType {
  mock,
  setuSandbox,
  razorpaySandbox,
}

/// Contract for bank balance & external transaction synchronization providers.
abstract class IBalanceSyncProvider {
  ProviderType get providerType;

  /// Authenticates with the provider (or checks cached credentials).
  Future<bool> authenticate();

  /// Fetches the latest known real bank balance and recent transactions.
  Future<BalanceSyncResult> fetchCurrentBalanceAndTransactions({DateTime? since});
}
