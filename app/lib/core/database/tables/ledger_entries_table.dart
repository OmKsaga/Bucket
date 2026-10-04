import 'package:drift/drift.dart';

class LedgerEntriesTable extends Table {
  @override
  String get tableName => 'ledger_entries';

  TextColumn get id => text()();
  TextColumn get bucketId => text().nullable()();
  TextColumn get transactionType => text()();
  IntColumn get amountDeltaPaise => integer()();
  IntColumn get balanceAfterPaise => integer()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
