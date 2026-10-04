import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_app/core/networking/api_client.dart';
import 'package:bucket_app/core/notifications/notification_service.dart';

void main() {
  group('NotificationService Unit Tests', () {
    test('dispatches and records goal milestone notifications', () {
      final client = ApiClient(baseUrl: 'http://localhost:8000/api/v1');
      final notifService = NotificationService(apiClient: client);

      expect(notifService.history.isEmpty, isTrue);

      notifService.notifyGoalMilestone(
        bucketName: 'MacBook Pro',
        percentage: 50,
      );

      expect(notifService.history.length, equals(1));
      final notif = notifService.history.first;
      expect(notif.type, equals(NotificationType.goalMilestone));
      expect(notif.title.contains('Milestone'), isTrue);
      expect(notif.body.contains('50%'), isTrue);
      expect(notif.body.contains('MacBook Pro'), isTrue);
    });

    test('dispatches waterfall drain alerts correctly', () {
      final client = ApiClient(baseUrl: 'http://localhost:8000/api/v1');
      final notifService = NotificationService(apiClient: client);

      notifService.notifyWaterfallDrain(
        bucketName: 'Video Games',
        deductedRupees: 2500,
      );

      expect(notifService.history.length, equals(1));
      final notif = notifService.history.first;
      expect(notif.type, equals(NotificationType.waterfallDrain));
      expect(notif.title.contains('Protection'), isTrue);
      expect(notif.body.contains('₹2500'), isTrue);
      expect(notif.body.contains('Video Games'), isTrue);
    });

    test('dispatches deadline approaching reminder', () {
      final client = ApiClient(baseUrl: 'http://localhost:8000/api/v1');
      final notifService = NotificationService(apiClient: client);

      notifService.notifyDeadlineApproaching(
        bucketName: 'Car Insurance',
        daysRemaining: 7,
      );

      expect(notifService.history.length, equals(1));
      final notif = notifService.history.first;
      expect(notif.type, equals(NotificationType.deadlineApproaching));
      expect(notif.body.contains('7 days left'), isTrue);
    });
  });
}
