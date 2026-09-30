import 'package:intl/intl.dart';

/// Type of financial bucket: Need or Want.
enum BucketType {
  need,
  want,
}

/// Append-only ledger mutation types.
enum TransactionType {
  initialAllocation,
  manualAdd,
  manualRemove,
  reallocation,
  externalSpendImpact,
  incomeDetected,
  refundDetected,
  reversal,
  goalCompleted,
}

/// Represents a virtual goal allocation bucket.
class Bucket {
  final String id;
  final String name;
  final String icon;
  final int targetAmountPaise;
  final int currentAllocationPaise;
  final DateTime? deadline;
  final String category;
  final BucketType type;
  final int priority; // 1 (lowest) to 5 (highest)
  final bool isProtected;
  final bool isCompleted;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Bucket({
    required this.id,
    required this.name,
    required this.icon,
    required this.targetAmountPaise,
    this.currentAllocationPaise = 0,
    this.deadline,
    required this.category,
    required this.type,
    required this.priority,
    this.isProtected = false,
    this.isCompleted = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get targetRupees => targetAmountPaise / 100.0;
  double get currentRupees => currentAllocationPaise / 100.0;
  double get progressPercentage =>
      targetAmountPaise > 0 ? (currentAllocationPaise / targetAmountPaise).clamp(0.0, 1.0) : 0.0;

  String get formattedCurrent => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(currentRupees);
  String get formattedTarget => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(targetRupees);
}

/// Represents an immutable ledger transaction entry.
class LedgerEntry {
  final String id;
  final String? bucketId;
  final TransactionType transactionType;
  final int amountDeltaPaise;
  final int balanceAfterPaise;
  final String? referenceId;
  final String? note;
  final DateTime timestamp;

  const LedgerEntry({
    required this.id,
    this.bucketId,
    required this.transactionType,
    required this.amountDeltaPaise,
    required this.balanceAfterPaise,
    this.referenceId,
    this.note,
    required this.timestamp,
  });

  double get deltaRupees => amountDeltaPaise / 100.0;
}

/// Represents the linked bank account summary.
class Account {
  final String id;
  final String accountNumberMask;
  final String bankName;
  final int totalBalancePaise;
  final DateTime lastSyncedAt;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.accountNumberMask,
    required this.bankName,
    required this.totalBalancePaise,
    required this.lastSyncedAt,
    required this.createdAt,
  });

  double get totalRupees => totalBalancePaise / 100.0;
  String get formattedBalance => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(totalRupees);
}

/// Outcome of a synchronization run.
class SyncSession {
  final String id;
  final String sessionHash;
  final int previousBalancePaise;
  final int currentBalancePaise;
  final int differencePaise;
  final String classification;
  final String? impactSummaryJson;
  final String status;
  final DateTime createdAt;

  const SyncSession({
    required this.id,
    required this.sessionHash,
    required this.previousBalancePaise,
    required this.currentBalancePaise,
    required this.differencePaise,
    required this.classification,
    this.impactSummaryJson,
    required this.status,
    required this.createdAt,
  });
}
