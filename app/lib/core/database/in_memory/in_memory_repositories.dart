import 'dart:async';
import '../../../domain/models/models.dart';
import '../../../domain/repositories/repositories.dart';

/// In-memory implementation of IBucketRepository.
class InMemoryBucketRepository implements IBucketRepository {
  final Map<String, Bucket> _buckets = {};
  final StreamController<List<Bucket>> _streamController = StreamController<List<Bucket>>.broadcast();

  InMemoryBucketRepository([List<Bucket>? initial]) {
    if (initial != null) {
      for (final b in initial) {
        _buckets[b.id] = b;
      }
    }
    _notify();
  }

  void _notify() {
    if (!_streamController.isClosed) {
      _streamController.add(List.unmodifiable(_buckets.values.toList()));
    }
  }

  @override
  Future<List<Bucket>> getAllBuckets() async {
    return List.unmodifiable(_buckets.values.toList());
  }

  @override
  Future<List<Bucket>> getActiveBucketsSorted() async {
    final active = _buckets.values.where((b) => !b.isCompleted).toList();
    // Sorted by priority ascending (1 -> 5)
    active.sort((a, b) {
      final prioComp = a.priority.compareTo(b.priority);
      if (prioComp != 0) return prioComp;
      return a.createdAt.compareTo(b.createdAt);
    });
    return List.unmodifiable(active);
  }

  @override
  Future<Bucket?> getBucketById(String id) async {
    return _buckets[id];
  }

  @override
  Future<void> saveBucket(Bucket bucket) async {
    _buckets[bucket.id] = bucket;
    _notify();
  }

  @override
  Future<void> updateBucket(Bucket bucket) async {
    if (!_buckets.containsKey(bucket.id)) {
      throw StateError('Bucket with id ${bucket.id} does not exist.');
    }
    _buckets[bucket.id] = bucket;
    _notify();
  }

  @override
  Future<void> deleteBucket(String id) async {
    _buckets.remove(id);
    _notify();
  }

  @override
  Stream<List<Bucket>> watchAllBuckets() => _streamController.stream;

  void dispose() {
    _streamController.close();
  }
}

/// In-memory implementation of ILedgerRepository.
class InMemoryLedgerRepository implements ILedgerRepository {
  final List<LedgerEntry> _entries = [];
  final StreamController<List<LedgerEntry>> _streamController = StreamController<List<LedgerEntry>>.broadcast();

  InMemoryLedgerRepository([List<LedgerEntry>? initial]) {
    if (initial != null) {
      _entries.addAll(initial);
    }
    _notify();
  }

  void _notify() {
    if (!_streamController.isClosed) {
      _streamController.add(List.unmodifiable(_entries));
    }
  }

  @override
  Future<void> appendEntry(LedgerEntry entry) async {
    _entries.add(entry);
    _notify();
  }

  @override
  Future<void> appendEntries(List<LedgerEntry> entries) async {
    _entries.addAll(entries);
    _notify();
  }

  @override
  Future<List<LedgerEntry>> getAllEntries() async {
    return List.unmodifiable(_entries);
  }

  @override
  Future<List<LedgerEntry>> getEntriesForBucket(String bucketId) async {
    return List.unmodifiable(_entries.where((e) => e.bucketId == bucketId).toList());
  }

  @override
  Future<List<LedgerEntry>> getRecentEntries(int limit) async {
    final reversed = _entries.reversed.toList();
    return List.unmodifiable(reversed.take(limit).toList());
  }

  @override
  Future<int> computeDerivedBalanceForBucket(String bucketId) async {
    return _entries
        .where((e) => e.bucketId == bucketId)
        .fold<int>(0, (sum, entry) => sum + entry.amountDeltaPaise);
  }

  @override
  Stream<List<LedgerEntry>> watchLedger() => _streamController.stream;

  void dispose() {
    _streamController.close();
  }
}

/// In-memory implementation of IAccountRepository.
class InMemoryAccountRepository implements IAccountRepository {
  Account? _account;
  final StreamController<Account?> _streamController = StreamController<Account?>.broadcast();

  InMemoryAccountRepository([this._account]) {
    _notify();
  }

  void _notify() {
    if (!_streamController.isClosed) {
      _streamController.add(_account);
    }
  }

  @override
  Future<Account?> getAccount() async => _account;

  @override
  Future<void> saveAccount(Account account) async {
    _account = account;
    _notify();
  }

  @override
  Future<void> updateBalance(int newBalancePaise) async {
    if (_account == null) {
      throw StateError('Cannot update balance: No linked account exists.');
    }
    _account = _account!.copyWith(totalBalancePaise: newBalancePaise);
    _notify();
  }

  @override
  Future<void> updateLastSynced(DateTime timestamp) async {
    if (_account == null) {
      throw StateError('Cannot update sync timestamp: No linked account exists.');
    }
    _account = _account!.copyWith(lastSyncedAt: timestamp);
    _notify();
  }

  @override
  Stream<Account?> watchAccount() => _streamController.stream;

  void dispose() {
    _streamController.close();
  }
}

/// In-memory implementation of ISyncSessionRepository.
class InMemorySyncSessionRepository implements ISyncSessionRepository {
  final Map<String, SyncSession> _sessionsByHash = {};
  final List<SyncSession> _sessionsList = [];

  @override
  Future<void> saveSession(SyncSession session) async {
    _sessionsByHash[session.sessionHash] = session;
    _sessionsList.add(session);
  }

  @override
  Future<SyncSession?> getSessionByHash(String hash) async {
    return _sessionsByHash[hash];
  }

  @override
  Future<List<SyncSession>> getRecentSessions(int limit) async {
    return List.unmodifiable(_sessionsList.reversed.take(limit).toList());
  }

  @override
  Future<bool> isSessionProcessed(String hash) async {
    return _sessionsByHash.containsKey(hash);
  }
}

/// In-memory implementation of ISettingsRepository.
class InMemorySettingsRepository implements ISettingsRepository {
  final Map<String, String> _settings = {};

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<Map<String, String>> getAllSettings() async => Map.unmodifiable(_settings);
}
