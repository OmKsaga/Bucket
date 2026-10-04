import 'package:drift/drift.dart';

class SyncSessionsTable extends Table {
  @override
  String get tableName => 'sync_sessions';

  TextColumn get id => text()();
  TextColumn get sessionHash => text().unique()();
  IntColumn get previousBalancePaise => integer()();
  IntColumn get currentBalancePaise => integer()();
  IntColumn get differencePaise => integer()();
  TextColumn get classification => text()();
  TextColumn get impactSummaryJson => text().nullable()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
