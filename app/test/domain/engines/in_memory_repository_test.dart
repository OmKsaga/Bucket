import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/domain/models/models.dart';
import 'package:bucket_app/core/database/in_memory/in_memory_repositories.dart';

void main() {
  group('InMemoryRepositories Tests', () {
    final now = DateTime(2026, 10, 1);

    test('InMemoryBucketRepository CRUD and priority ordering', () async {
      final repo = InMemoryBucketRepository();

      final b1 = Bucket(
        id: '1',
        name: 'Shoes',
        icon: '👟',
        targetAmountPaise: 500000,
        category: 'Shopping',
        type: BucketType.want,
        priority: 2,
        createdAt: now,
        updatedAt: now,
      );

      final b2 = Bucket(
        id: '2',
        name: 'Rent',
        icon: '🏠',
        targetAmountPaise: 1000000,
        category: 'Housing',
        type: BucketType.need,
        priority: 5,
        createdAt: now,
        updatedAt: now,
      );

      final b3 = Bucket(
        id: '3',
        name: 'PS5',
        icon: '🎮',
        targetAmountPaise: 5000000,
        category: 'Gaming',
        type: BucketType.want,
        priority: 1,
        createdAt: now,
        updatedAt: now,
      );

      await repo.saveBucket(b1);
      await repo.saveBucket(b2);
      await repo.saveBucket(b3);

      final all = await repo.getAllBuckets();
      expect(all.length, equals(3));

      // Sorted active buckets should be P1 (PS5), P2 (Shoes), P5 (Rent)
      final sorted = await repo.getActiveBucketsSorted();
      expect(sorted[0].name, equals('PS5'));
      expect(sorted[1].name, equals('Shoes'));
      expect(sorted[2].name, equals('Rent'));

      // Update
      final updated = b1.copyWith(name: 'Sneakers');
      await repo.updateBucket(updated);
      final fetched = await repo.getBucketById('1');
      expect(fetched?.name, equals('Sneakers'));

      // Delete
      await repo.deleteBucket('1');
      expect(await repo.getBucketById('1'), isNull);
    });

    test('InMemoryLedgerRepository derives balance from append-only entries', () async {
      final repo = InMemoryLedgerRepository();

      await repo.appendEntry(LedgerEntry(
        id: 'e1',
        bucketId: 'b1',
        transactionType: TransactionType.initialAllocation,
        amountDeltaPaise: 100000, // +₹1,000
        balanceAfterPaise: 100000,
        timestamp: now,
      ));

      await repo.appendEntry(LedgerEntry(
        id: 'e2',
        bucketId: 'b1',
        transactionType: TransactionType.manualAdd,
        amountDeltaPaise: 250000, // +₹2,500
        balanceAfterPaise: 350000,
        timestamp: now,
      ));

      await repo.appendEntry(LedgerEntry(
        id: 'e3',
        bucketId: 'b1',
        transactionType: TransactionType.externalSpendImpact,
        amountDeltaPaise: -50000, // -₹500
        balanceAfterPaise: 300000,
        timestamp: now,
      ));

      final derived = await repo.computeDerivedBalanceForBucket('b1');
      expect(derived, equals(300000)); // ₹3,000

      final entries = await repo.getEntriesForBucket('b1');
      expect(entries.length, equals(3));
    });

    test('InMemorySyncSessionRepository detects duplicate session hashes', () async {
      final repo = InMemorySyncSessionRepository();

      final session = SyncSession(
        id: 's1',
        sessionHash: 'hash_abc123',
        previousBalancePaise: 3000000,
        currentBalancePaise: 2400000,
        differencePaise: -600000,
        classification: 'EXTERNAL_SPEND',
        status: 'COMPLETED',
        createdAt: now,
      );

      expect(await repo.isSessionProcessed('hash_abc123'), isFalse);
      await repo.saveSession(session);
      expect(await repo.isSessionProcessed('hash_abc123'), isTrue);
    });
  });
}
