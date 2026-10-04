import 'dart:async';
import 'package:uuid/uuid.dart';
import 'sync_provider.dart';

/// Configurable mock provider simulating bank/UPI sync behavior and external statements.
class MockSyncProvider implements IBalanceSyncProvider {
  static const _uuid = Uuid();

  int _currentBankBalancePaise;
  bool _isOffline = false;
  Duration _simulatedLatency = const Duration(milliseconds: 400);
  final List<ExternalTransaction> _pendingTransactions = [];

  MockSyncProvider({
    int initialBalancePaise = 3000000, // ₹30,000
    Duration? simulatedLatency,
  })  : _currentBankBalancePaise = initialBalancePaise,
        _simulatedLatency = simulatedLatency ?? const Duration(milliseconds: 400);

  @override
  ProviderType get providerType => ProviderType.mock;

  int get currentBankBalancePaise => _currentBankBalancePaise;

  void setOffline(bool offline) {
    _isOffline = offline;
  }

  void setLatency(Duration latency) {
    _simulatedLatency = latency;
  }

  /// Sets balance directly for testing.
  void setBankBalance(int balancePaise) {
    _currentBankBalancePaise = balancePaise;
  }

  /// Simulates an external card/UPI spend done outside the app.
  void simulateExternalSpend({
    required int amountPaise,
    required String merchantName,
    DateTime? timestamp,
  }) {
    if (amountPaise <= 0) throw ArgumentError('Amount must be > 0');
    _currentBankBalancePaise -= amountPaise;

    _pendingTransactions.add(ExternalTransaction(
      id: _uuid.v4(),
      amountPaise: amountPaise,
      type: ExternalTransactionType.debit,
      description: 'POS Swipe / UPI at $merchantName',
      merchantName: merchantName,
      timestamp: timestamp ?? DateTime.now(),
    ));
  }

  /// Simulates incoming salary or money transfer from external bank.
  void simulateIncomingMoney({
    required int amountPaise,
    required String source,
    DateTime? timestamp,
  }) {
    if (amountPaise <= 0) throw ArgumentError('Amount must be > 0');
    _currentBankBalancePaise += amountPaise;

    _pendingTransactions.add(ExternalTransaction(
      id: _uuid.v4(),
      amountPaise: amountPaise,
      type: ExternalTransactionType.credit,
      description: 'NEFT / UPI Credit from $source',
      merchantName: source,
      timestamp: timestamp ?? DateTime.now(),
    ));
  }

  /// Simulates a merchant refund or payment reversal.
  void simulateRefund({
    required int amountPaise,
    required String merchantName,
    String? referenceId,
    DateTime? timestamp,
  }) {
    if (amountPaise <= 0) throw ArgumentError('Amount must be > 0');
    _currentBankBalancePaise += amountPaise;

    _pendingTransactions.add(ExternalTransaction(
      id: _uuid.v4(),
      amountPaise: amountPaise,
      type: ExternalTransactionType.refund,
      description: 'UPI Refund from $merchantName',
      merchantName: merchantName,
      referenceId: referenceId,
      timestamp: timestamp ?? DateTime.now(),
    ));
  }

  @override
  Future<bool> authenticate() async {
    if (_isOffline) {
      throw const AsyncError(
        'Network error: Unable to contact bank authorization server.',
        StackTrace.empty,
      );
    }
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  @override
  Future<BalanceSyncResult> fetchCurrentBalanceAndTransactions({DateTime? since}) async {
    if (_isOffline) {
      throw StateError('Network offline: Failed to connect to bank server.');
    }

    if (_simulatedLatency.inMilliseconds > 0) {
      await Future.delayed(_simulatedLatency);
    }

    final txList = List<ExternalTransaction>.from(_pendingTransactions);
    _pendingTransactions.clear();

    return BalanceSyncResult(
      currentBalancePaise: _currentBankBalancePaise,
      timestamp: DateTime.now(),
      transactions: txList,
      rawMetadata: {
        'provider': 'MockBankProvider',
        'institution': 'HDFC Bank Sandbox',
        'currency': 'INR',
      },
    );
  }
}
