import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/accounts_table.dart';
import 'tables/buckets_table.dart';
import 'tables/ledger_entries_table.dart';
import 'tables/sync_sessions_table.dart';
import 'tables/app_settings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  AccountsTable,
  BucketsTable,
  LedgerEntriesTable,
  SyncSessionsTable,
  AppSettingsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'bucket_wallet_db');
  }
}
