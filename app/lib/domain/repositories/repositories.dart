import '../models/models.dart';

abstract class IBucketRepository {
  Future<List<Bucket>> getAllBuckets();
  Future<List<Bucket>> getActiveBucketsSorted();
  Future<Bucket?> getBucketById(String id);
  Future<void> saveBucket(Bucket bucket);
  Future<void> updateBucket(Bucket bucket);
  Future<void> deleteBucket(String id);
  Stream<List<Bucket>> watchAllBuckets();
}

abstract class ILedgerRepository {
  Future<void> appendEntry(LedgerEntry entry);
  Future<void> appendEntries(List<LedgerEntry> entries);
  Future<List<LedgerEntry>> getAllEntries();
  Future<List<LedgerEntry>> getEntriesForBucket(String bucketId);
  Future<List<LedgerEntry>> getRecentEntries(int limit);
  Future<int> computeDerivedBalanceForBucket(String bucketId);
  Stream<List<LedgerEntry>> watchLedger();
}

abstract class IAccountRepository {
  Future<Account?> getAccount();
  Future<void> saveAccount(Account account);
  Future<void> updateBalance(int newBalancePaise);
  Future<void> updateLastSynced(DateTime timestamp);
  Stream<Account?> watchAccount();
}

abstract class ISyncSessionRepository {
  Future<void> saveSession(SyncSession session);
  Future<SyncSession?> getSessionByHash(String hash);
  Future<List<SyncSession>> getRecentSessions(int limit);
  Future<bool> isSessionProcessed(String hash);
}

abstract class ISettingsRepository {
  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
  Future<Map<String, String>> getAllSettings();
}
