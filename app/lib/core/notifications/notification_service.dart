import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../networking/api_client.dart';
import '../../features/auth/services/auth_service.dart';

enum NotificationType {
  syncComplete,
  goalMilestone,
  deadlineApproaching,
  waterfallDrain,
  syncReminder,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
  });
}

class NotificationService {
  final ApiClient apiClient;
  final List<AppNotification> _notificationsHistory = [];
  final StreamController<AppNotification> _notificationStream = StreamController.broadcast();

  NotificationService({required this.apiClient});

  Stream<AppNotification> get onNotification => _notificationStream.stream;
  List<AppNotification> get history => List.unmodifiable(_notificationsHistory);

  Future<void> registerFCMToken(String token, {String platform = 'android'}) async {
    try {
      await apiClient.registerDevice(deviceToken: token, platform: platform);
    } catch (_) {}
  }

  void notify({
    required String title,
    required String body,
    required NotificationType type,
  }) {
    final notification = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
    );

    _notificationsHistory.insert(0, notification);
    _notificationStream.add(notification);
  }

  void notifyGoalMilestone({
    required String bucketName,
    required int percentage,
  }) {
    notify(
      title: '🎯 Milestone Reached!',
      body: 'Your "$bucketName" goal is now $percentage% funded! Keep up the great pace.',
      type: NotificationType.goalMilestone,
    );
  }

  void notifyWaterfallDrain({
    required String bucketName,
    required int deductedRupees,
  }) {
    notify(
      title: '🛡️ Goal Protection Triggered',
      body: '₹$deductedRupees was absorbed from lowest-priority "$bucketName" to protect your essential goals.',
      type: NotificationType.waterfallDrain,
    );
  }

  void notifyDeadlineApproaching({
    required String bucketName,
    required int daysRemaining,
  }) {
    notify(
      title: '⏰ Deadline Approaching',
      body: 'Only $daysRemaining days left for "$bucketName". Check your daily run rate.',
      type: NotificationType.deadlineApproaching,
    );
  }

  void notifySyncReminder() {
    notify(
      title: '🔄 Sync Reminder',
      body: 'You haven\'t synced with your bank in over 24 hours. Sync now to reconcile allocations.',
      type: NotificationType.syncReminder,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final client = ref.watch(apiClientProvider);
  return NotificationService(apiClient: client);
});
