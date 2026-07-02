import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../shared/theme/app_theme.dart';
import '../../premium/bloc/premium_bloc.dart';
import '../../premium/services/iap_service.dart';
import '../../auth/bloc/auth_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _useBiometrics = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    context.read<PremiumBloc>().add(PremiumLoadOfferings());
  }

  Future<void> _loadSettings() async {
    final useBioStr = await _secureStorage.read(key: 'use_biometrics');
    setState(() {
      _useBiometrics = useBioStr == null || useBioStr == 'true';
      _isLoading = false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    setState(() => _useBiometrics = value);
    await _secureStorage.write(key: 'use_biometrics', value: value.toString());
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Delete All Data?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'This will permanently delete all your stored passwords, documents, and reset your master password. This action cannot be undone.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete Everything', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _secureStorage.deleteAll();
      await Hive.deleteBoxFromDisk('vault_box');

      if (mounted) {
        context.read<AuthBloc>().add(AuthCheckStatus());
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GradientScaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryCyan)));
    }

    return GradientScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Security Section
          _buildSectionLabel('SECURITY', AppColors.primaryCyan),
          const SizedBox(height: 10),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Biometric Unlock', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                  subtitle: const Text('Use Fingerprint or Face ID', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  value: _useBiometrics,
                  onChanged: _toggleBiometrics,
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fingerprint, color: AppColors.primaryCyan),
                  ),
                ),
                const Divider(indent: 70),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppColors.textMuted),
                  ),
                  title: const Text('Change Master Password', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                  subtitle: const Text('Coming soon', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming in a future update')));
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Subscription Section
          _buildSectionLabel('SUBSCRIPTION', AppColors.accentAmber),
          const SizedBox(height: 10),
          BlocBuilder<PremiumBloc, PremiumState>(
            builder: (context, state) {
              SubscriptionTier tier = SubscriptionTier.free;
              if (state is PremiumLoaded) tier = state.currentTier;
              final isPremium = tier != SubscriptionTier.free;

              return GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: isPremium ? AppColors.goldGradient : null,
                        color: isPremium ? null : AppColors.textMuted.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        isPremium ? Icons.workspace_premium_rounded : Icons.star_outline_rounded,
                        color: isPremium ? AppColors.bgDark : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPremium ? 'Premium Active' : 'Free Tier',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPremium ? 'Thank you for your support!' : 'Upgrade for unlimited access',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (!isPremium)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: AppColors.primaryGradient,
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(90, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () => context.push('/paywall'),
                          child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      )
                    else
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Danger Zone
          _buildSectionLabel('DANGER ZONE', AppColors.error),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              color: AppColors.error.withValues(alpha: 0.05),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
              ),
              title: const Text('Delete All Data', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              subtitle: const Text('Erase all passwords & reset app', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.error),
              onTap: _deleteAllData,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 1.5,
      ),
    );
  }
}
