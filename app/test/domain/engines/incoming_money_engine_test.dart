import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/domain/models/models.dart';
import 'package:bucket_app/domain/engines/incoming_money_engine.dart';

void main() {
  group('IncomingMoneyEngine Tests', () {
    test('processIncoming credits unallocated balance and writes INCOME_DETECTED', () {
      final result = IncomingMoneyEngine.processIncoming(
        incomingAmountPaise: 2500000, // ₹25,000 salary
        currentUnallocatedPaise: 500000, // ₹5,000 existing
        note: 'October Salary',
      );

      expect(result.incomingAmountPaise, equals(2500000));
      expect(result.previousUnallocatedPaise, equals(500000));
      expect(result.newUnallocatedPaise, equals(3000000)); // ₹30,000

      expect(result.ledgerEntry.transactionType, equals(TransactionType.incomeDetected));
      expect(result.ledgerEntry.amountDeltaPaise, equals(2500000));
      expect(result.ledgerEntry.balanceAfterPaise, equals(3000000));
      expect(result.ledgerEntry.bucketId, isNull); // Credited to unallocated pool
      expect(result.ledgerEntry.note, equals('October Salary'));
    });

    test('processIncoming zero or negative amount throws ArgumentError', () {
      expect(
        () => IncomingMoneyEngine.processIncoming(
          incomingAmountPaise: 0,
          currentUnallocatedPaise: 1000,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => IncomingMoneyEngine.processIncoming(
          incomingAmountPaise: -500,
          currentUnallocatedPaise: 1000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
