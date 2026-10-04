import 'package:intl/intl.dart';

/// Type of financial bucket: Need or Want.
enum BucketType {
  need,
  want;

  static BucketType fromString(String val) {
    return val.toLowerCase() == 'need' ? BucketType.need : BucketType.want;
  }
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
  goalCompleted;

  static TransactionType fromString(String val) {
    for (final type in TransactionType.values) {
      if (type.name.toLowerCase() == val.toLowerCase()) {
        return type;
      }
    }
    return TransactionType.initialAllocation;
  }
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
  final int priority; // 1 (lowest / first to sacrifice) to 5 (highest / last to sacrifice)
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

  String get formattedCurrent =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(currentRupees);
  String get formattedTarget =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(targetRupees);

  Bucket copyWith({
    String? id,
    String? name,
    String? icon,
    int? targetAmountPaise,
    int? currentAllocationPaise,
    DateTime? deadline,
    String? category,
    BucketType? type,
    int? priority,
    bool? isProtected,
    bool? isCompleted,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Bucket(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      targetAmountPaise: targetAmountPaise ?? this.targetAmountPaise,
      currentAllocationPaise: currentAllocationPaise ?? this.currentAllocationPaise,
      deadline: deadline ?? this.deadline,
      category: category ?? this.category,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isProtected: isProtected ?? this.isProtected,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'target_amount_paise': targetAmountPaise,
      'current_allocation_paise': currentAllocationPaise,
      'deadline': deadline?.toIso8601String(),
      'category': category,
      'type': type.name,
      'priority': priority,
      'is_protected': isProtected ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Bucket.fromMap(Map<String, dynamic> map) {
    return Bucket(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      targetAmountPaise: map['target_amount_paise'] as int,
      currentAllocationPaise: (map['current_allocation_paise'] as int?) ?? 0,
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline'] as String) : null,
      category: map['category'] as String,
      type: BucketType.fromString(map['type'] as String),
      priority: map['priority'] as int,
      isProtected: (map['is_protected'] as int?) == 1,
      isCompleted: (map['is_completed'] as int?) == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bucket &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          currentAllocationPaise == other.currentAllocationPaise &&
          targetAmountPaise == other.targetAmountPaise &&
          priority == other.priority &&
          type == other.type &&
          isProtected == other.isProtected;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      currentAllocationPaise.hashCode ^
      targetAmountPaise.hashCode ^
      priority.hashCode ^
      type.hashCode ^
      isProtected.hashCode;

  @override
  String toString() =>
      'Bucket(id: $id, name: $name, bal: ₹$currentRupees/₹$targetRupees, P$priority, $type, protected: $isProtected)';
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
  double get balanceAfterRupees => balanceAfterPaise / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bucket_id': bucketId,
      'transaction_type': transactionType.name,
      'amount_delta_paise': amountDeltaPaise,
      'balance_after_paise': balanceAfterPaise,
      'reference_id': referenceId,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LedgerEntry.fromMap(Map<String, dynamic> map) {
    return LedgerEntry(
      id: map['id'] as String,
      bucketId: map['bucket_id'] as String?,
      transactionType: TransactionType.fromString(map['transaction_type'] as String),
      amountDeltaPaise: map['amount_delta_paise'] as int,
      balanceAfterPaise: map['balance_after_paise'] as int,
      referenceId: map['reference_id'] as String?,
      note: map['note'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bucketId == other.bucketId &&
          transactionType == other.transactionType &&
          amountDeltaPaise == other.amountDeltaPaise &&
          balanceAfterPaise == other.balanceAfterPaise;

  @override
  int get hashCode =>
      id.hashCode ^
      bucketId.hashCode ^
      transactionType.hashCode ^
      amountDeltaPaise.hashCode ^
      balanceAfterPaise.hashCode;

  @override
  String toString() =>
      'LedgerEntry(id: $id, bucket: $bucketId, type: $transactionType, delta: ₹$deltaRupees, after: ₹$balanceAfterRupees)';
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
  String get formattedBalance =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(totalRupees);

  Account copyWith({
    String? id,
    String? accountNumberMask,
    String? bankName,
    int? totalBalancePaise,
    DateTime? lastSyncedAt,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      accountNumberMask: accountNumberMask ?? this.accountNumberMask,
      bankName: bankName ?? this.bankName,
      totalBalancePaise: totalBalancePaise ?? this.totalBalancePaise,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_number_mask': accountNumberMask,
      'bank_name': bankName,
      'total_balance_paise': totalBalancePaise,
      'last_synced_at': lastSyncedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      accountNumberMask: map['account_number_mask'] as String,
      bankName: map['bank_name'] as String,
      totalBalancePaise: map['total_balance_paise'] as int,
      lastSyncedAt: DateTime.parse(map['last_synced_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          totalBalancePaise == other.totalBalancePaise;

  @override
  int get hashCode => id.hashCode ^ totalBalancePaise.hashCode;

  @override
  String toString() => 'Account(id: $id, $bankName, bal: ₹$totalRupees, synced: $lastSyncedAt)';
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_hash': sessionHash,
      'previous_balance_paise': previousBalancePaise,
      'current_balance_paise': currentBalancePaise,
      'difference_paise': differencePaise,
      'classification': classification,
      'impact_summary_json': impactSummaryJson,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncSession.fromMap(Map<String, dynamic> map) {
    return SyncSession(
      id: map['id'] as String,
      sessionHash: map['session_hash'] as String,
      previousBalancePaise: map['previous_balance_paise'] as int,
      currentBalancePaise: map['current_balance_paise'] as int,
      differencePaise: map['difference_paise'] as int,
      classification: map['classification'] as String,
      impactSummaryJson: map['impact_summary_json'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Represents application configuration settings.
class AppSetting {
  final String key;
  final String value;
  final DateTime updatedAt;

  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      key: map['key'] as String,
      value: map['value'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
