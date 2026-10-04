import 'package:drift/drift.dart';

class BucketsTable extends Table {
  @override
  String get tableName => 'buckets';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get targetAmountPaise => integer()();
  IntColumn get currentAllocationPaise => integer().withDefault(const Constant(0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get category => text()();
  TextColumn get type => text()(); // 'need' or 'want'
  IntColumn get priority => integer()(); // 1 to 5
  BoolColumn get isProtected => boolean().withDefault(const Constant(false))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
