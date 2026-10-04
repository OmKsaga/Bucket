import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/security/biometric_service.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;

  const BiometricLockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometricAuth();
    });
  }

  Future<void> _triggerBiometricAuth() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final bioService = ref.read(biometricSecurityServiceProvider);
    final success = await bioService.authenticate();

    if (mounted) {
      setState(() => _isAuthenticating = false);
      if (success) {
        bioService.unlock();
        widget.onUnlocked();
      } else {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryAccent.withOpacity(0.12),
                    border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 64,
                    color: AppTheme.primaryAccent,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Bucket is Locked',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Confirm your identity to access your virtual allocations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white60),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.dangerRose, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  onPressed: _isAuthenticating ? null : _triggerBiometricAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  icon: const Icon(Icons.lock_open_rounded, size: 20),
                  label: Text(_isAuthenticating ? 'Scanning...' : 'Unlock Now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
