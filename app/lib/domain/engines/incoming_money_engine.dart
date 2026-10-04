import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// Result returned when incoming money / salary is detected.
class IncomingMoneyResult {
  final int incomingAmountPaise;
  final int previousUnallocatedPaise;
  final int newUnallocatedPaise;
  final LedgerEntry ledgerEntry;

  const IncomingMoneyResult({
    required this.incomingAmountPaise,
    required this.previousUnallocatedPaise,
    required this.newUnallocatedPaise,
    required this.ledgerEntry,
  });

  double get incomingRupees => incomingAmountPaise / 100.0;
  double get newUnallocatedRupees => newUnallocatedPaise / 100.0;
}

/// Core engine managing incoming money, salary detection, and unallocated pool crediting.
class IncomingMoneyEngine {
  static const _uuid = Uuid();

  /// Processes an increase in bank balance.
  /// Rule: By default, money is NOT auto-distributed to buckets; it goes to unallocated.
  static IncomingMoneyResult processIncoming({
    required int incomingAmountPaise,
    required int currentUnallocatedPaise,
    String? note,
    String? referenceId,
    DateTime? timestamp,
  }) {
    if (incomingAmountPaise <= 0) {
      throw ArgumentError.value(incomingAmountPaise, 'incomingAmountPaise', 'Incoming amount must be greater than 0.');
    }

    final effectiveTimestamp = timestamp ?? DateTime.now();
    final newUnallocated = currentUnallocatedPaise + incomingAmountPaise;

    final entry = LedgerEntry(
      id: _uuid.v4(),
      bucketId: null, // Unallocated pool
      transactionType: TransactionType.incomeDetected,
      amountDeltaPaise: incomingAmountPaise,
      balanceAfterPaise: newUnallocated,
      referenceId: referenceId,
      note: note ?? 'Detected incoming funds of ₹${incomingAmountPaise / 100}',
      timestamp: effectiveTimestamp,
    );

    return IncomingMoneyResult(
      incomingAmountPaise: incomingAmountPaise,
      previousUnallocatedPaise: currentUnallocatedPaise,
      newUnallocatedPaise: newUnallocated,
      ledgerEntry: entry,
    );
  }
}
