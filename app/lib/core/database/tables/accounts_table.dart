import 'package:drift/drift.dart';

class AccountsTable extends Table {
  @override
  String get tableName => 'accounts';

  TextColumn get id => text()();
  TextColumn get accountNumberMask => text()();
  TextColumn get bankName => text()();
  IntColumn get totalBalancePaise => integer()();
  DateTimeColumn get lastSyncedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
