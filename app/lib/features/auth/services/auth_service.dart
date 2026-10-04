import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/networking/api_client.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? userId;
  final int deviceCount;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.email,
    this.userId,
    this.deviceCount = 0,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? userId,
    int? deviceCount,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      deviceCount: deviceCount ?? this.deviceCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient apiClient;

  AuthNotifier({required this.apiClient}) : super(const AuthState()) {
    checkAuthSession();
  }

  Future<void> checkAuthSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await apiClient.initTokens();
      if (apiClient.isAuthenticated) {
        final profile = await apiClient.getProfile();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          email: profile['email'] as String?,
          userId: profile['id'] as String?,
          deviceCount: (profile['device_count'] as int?) ?? 0,
        );
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await apiClient.login(email: email, password: password);
      final profile = await apiClient.getProfile();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        email: profile['email'] as String?,
        userId: profile['id'] as String?,
        deviceCount: (profile['device_count'] as int?) ?? 0,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', '').replaceAll('HttpException: ', ''),
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await apiClient.register(email: email, password: password);
      final profile = await apiClient.getProfile();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        email: profile['email'] as String?,
        userId: profile['id'] as String?,
        deviceCount: (profile['device_count'] as int?) ?? 0,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', '').replaceAll('HttpException: ', ''),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await apiClient.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// Global Providers
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: 'http://localhost:8000/api/v1',
    secureStorage: const FlutterSecureStorage(),
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient: client);
});
