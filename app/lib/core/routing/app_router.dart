import 'package:go_router/go_router.dart';
import '../../features/main_scaffold.dart';
import '../../features/allocations/presentation/bucket_detail_screen.dart';
import '../../features/home/presentation/sync_simulator_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/payments/presentation/qr_scanner_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScaffold(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/qr-scanner',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/bucket/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BucketDetailScreen(bucketId: id);
        },
      ),
      GoRoute(
        path: '/sync-sim',
        builder: (context, state) => const SyncSimulatorScreen(),
      ),
    ],
  );
}
