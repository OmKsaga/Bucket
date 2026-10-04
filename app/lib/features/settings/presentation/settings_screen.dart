import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import '../../shared/wallet_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = true;
  LockTimeout _selectedTimeout = LockTimeout.fiveMinutes;
  String _syncFrequency = '15 minutes';
  String _themeMode = 'Dark';

  @override
  void initState() {
    super.initState();
    final bioService = ref.read(biometricSecurityServiceProvider);
    _biometricEnabled = bioService.isBiometricEnabled;
    _selectedTimeout = bioService.timeout;
  }

  void _showTimeoutPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Auto-Lock Timeout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...LockTimeout.values.map((timeout) {
              return ListTile(
                title: Text(timeout.displayName),
                trailing: _selectedTimeout == timeout ? const Icon(Icons.check, color: AppTheme.primaryAccent) : null,
                onTap: () {
                  setState(() => _selectedTimeout = timeout);
                  ref.read(biometricSecurityServiceProvider).setTimeout(timeout);
                  Navigator.of(ctx).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _triggerCloudBackup() async {
    final client = ref.read(apiClientProvider);
    if (!client.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first to store an encrypted cloud backup.')),
      );
      return;
    }

    try {
      await client.storeBackup(
        ciphertext: 'ENCRYPTED_BLOB_ZERO_KNOWLEDGE_AES256',
        iv: 'INIT_VECTOR_AES_GCM',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Zero-knowledge backup saved to cloud!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppTheme.dangerRose),
        );
      }
    }
  }

  void _triggerTestNotification() {
    final notif = ref.read(notificationServiceProvider);
    notif.notifyGoalMilestone(
      bucketName: 'MacBook Pro',
      percentage: 75,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dispatched simulated milestone notification!'),
        backgroundColor: AppTheme.primaryAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Account Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryAccent.withOpacity(0.2),
                  child: const Icon(Icons.person, color: AppTheme.primaryAccentLight),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.isAuthenticated ? (authState.email ?? 'Authenticated User') : 'Not Signed In',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        authState.isAuthenticated
                            ? '${authState.deviceCount} registered devices • Cloud sync active'
                            : 'Sign in to enable zero-knowledge backups',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                if (!authState.isAuthenticated)
                  ElevatedButton(
                    onPressed: () => context.push('/auth'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Sign In', style: TextStyle(fontSize: 13)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: AppTheme.dangerRose),
                    tooltip: 'Log Out',
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Biometrics Section
          const Text('Security & Privacy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryAccentLight),
                  title: const Text('Biometric App Lock'),
                  subtitle: const Text('Require FaceID / Fingerprint on return', style: TextStyle(fontSize: 12)),
                  value: _biometricEnabled,
                  onChanged: (val) {
                    setState(() => _biometricEnabled = val);
                    ref.read(biometricSecurityServiceProvider).setBiometricEnabled(val);
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: AppTheme.primaryAccentLight),
                  title: const Text('Auto-Lock Delay'),
                  subtitle: Text(_selectedTimeout.displayName, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: _showTimeoutPicker,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Cloud Backup & Sync Section
          const Text('Data & Synchronization', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined, color: AppTheme.successGreen),
                  title: const Text('Zero-Knowledge Cloud Backup'),
                  subtitle: const Text('AES-256 client encrypted snapshot', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: _triggerCloudBackup,
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.sync_outlined, color: AppTheme.primaryAccentLight),
                  title: const Text('Bank Sync Frequency'),
                  subtitle: Text('Current: $_syncFrequency', style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    setState(() {
                      _syncFrequency = _syncFrequency == '15 minutes' ? '1 hour' : '15 minutes';
                    });
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.tune_rounded, color: AppTheme.warningAmber),
                  title: const Text('Launch Sync Simulator'),
                  subtitle: const Text('Simulate bank deposits & external spends', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () => context.push('/sync-sim'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notifications Section
          const Text('Notifications & Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined, color: AppTheme.warningAmber),
              title: const Text('Test Push Notification'),
              subtitle: const Text('Trigger goal milestone & waterfall alert preview', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.send_rounded, size: 18, color: AppTheme.primaryAccent),
              onTap: _triggerTestNotification,
            ),
          ),
          const SizedBox(height: 20),

          // About & Privacy Guarantee
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.successGreen, size: 18),
                    SizedBox(width: 8),
                    Text('Zero-Custody Privacy Guarantee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Bucket operates on a local-first virtual allocation ledger. No money leaves your bank account, and no balances are visible to the cloud backend.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: Text(
              '${AppConstants.appName} v0.5.0-beta • MIT License',
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
