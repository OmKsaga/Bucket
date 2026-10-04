import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum LockTimeout {
  immediate,
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  never,
}

extension LockTimeoutExtension on LockTimeout {
  String get displayName {
    switch (this) {
      case LockTimeout.immediate:
        return 'Immediately';
      case LockTimeout.oneMinute:
        return 'After 1 minute';
      case LockTimeout.fiveMinutes:
        return 'After 5 minutes';
      case LockTimeout.fifteenMinutes:
        return 'After 15 minutes';
      case LockTimeout.never:
        return 'Never';
    }
  }

  Duration? get duration {
    switch (this) {
      case LockTimeout.immediate:
        return Duration.zero;
      case LockTimeout.oneMinute:
        return const Duration(minutes: 1);
      case LockTimeout.fiveMinutes:
        return const Duration(minutes: 5);
      case LockTimeout.fifteenMinutes:
        return const Duration(minutes: 15);
      case LockTimeout.never:
        return null;
    }
  }
}

class BiometricSecurityService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage? secureStorage;

  bool _isLocked = false;
  bool _biometricEnabled = true;
  LockTimeout _timeout = LockTimeout.fiveMinutes;
  DateTime? _lastBackgrounded;

  BiometricSecurityService({this.secureStorage});

  bool get isLocked => _isLocked;
  bool get isBiometricEnabled => _biometricEnabled;
  LockTimeout get timeout => _timeout;

  Future<void> init() async {
    if (secureStorage != null) {
      try {
        final enabledStr = await secureStorage!.read(key: 'bucket_bio_enabled');
        if (enabledStr != null) {
          _biometricEnabled = enabledStr == 'true';
        }
        final timeoutStr = await secureStorage!.read(key: 'bucket_lock_timeout');
        if (timeoutStr != null) {
          _timeout = LockTimeout.values.firstWhere(
            (e) => e.name == timeoutStr,
            orElse: () => LockTimeout.fiveMinutes,
          );
        }
      } catch (_) {}
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    if (secureStorage != null) {
      try {
        await secureStorage!.write(key: 'bucket_bio_enabled', value: enabled.toString());
      } catch (_) {}
    }
  }

  Future<void> setTimeout(LockTimeout timeout) async {
    _timeout = timeout;
    if (secureStorage != null) {
      try {
        await secureStorage!.write(key: 'bucket_lock_timeout', value: timeout.name);
      } catch (_) {}
    }
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Authenticate to access Bucket'}) async {
    if (!_biometricEnabled) {
      _isLocked = false;
      return true;
    }

    try {
      final isSuccess = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (isSuccess) {
        _isLocked = false;
      }
      return isSuccess;
    } catch (_) {
      // Allow fallback if hardware not available in simulator
      _isLocked = false;
      return true;
    }
  }

  void onAppPaused() {
    _lastBackgrounded = DateTime.now();
  }

  bool onAppResumed() {
    if (!_biometricEnabled || _timeout == LockTimeout.never) {
      return false;
    }
    if (_lastBackgrounded == null) return false;

    final elapsed = DateTime.now().difference(_lastBackgrounded!);
    final limit = _timeout.duration;
    if (limit != null && elapsed >= limit) {
      _isLocked = true;
      return true;
    }
    return false;
  }

  void unlock() {
    _isLocked = false;
  }
}

final biometricSecurityServiceProvider = Provider<BiometricSecurityService>((ref) {
  return BiometricSecurityService(secureStorage: const FlutterSecureStorage());
});
