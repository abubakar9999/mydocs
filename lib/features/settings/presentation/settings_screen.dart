import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text('This will permanently delete all your stored passwords and reset your master password. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear storage
      await _secureStorage.deleteAll();
      await Hive.deleteBoxFromDisk('vault_box');
      
      if (mounted) {
        // Reset app state
        context.read<AuthBloc>().add(AuthCheckStatus());
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Security Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('SECURITY', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
          ),
          SwitchListTile(
            title: const Text('Biometric Unlock'),
            subtitle: const Text('Use Fingerprint or Face ID to unlock the vault'),
            value: _useBiometrics,
            activeTrackColor: Colors.teal,
            onChanged: _toggleBiometrics,
          ),
          ListTile(
            title: const Text('Change Master Password'),
            subtitle: const Text('Feature coming in a future update.'),
            trailing: const Icon(Icons.lock_outline),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not implemented yet.')));
            },
          ),
          
          const Divider(height: 32),

          // Subscription Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('SUBSCRIPTION', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
          ),
          BlocBuilder<PremiumBloc, PremiumState>(
            builder: (context, state) {
              if (state is PremiumLoading) {
                return const ListTile(title: Text('Loading subscription status...'));
              }
              
              SubscriptionTier tier = SubscriptionTier.free;
              if (state is PremiumLoaded) {
                tier = state.currentTier;
              }

              final isPremium = tier != SubscriptionTier.free;
              
              return ListTile(
                title: Text(isPremium ? 'Premium Active' : 'Free Tier'),
                subtitle: Text(isPremium ? 'Thank you for supporting SecureVault!' : 'Upgrade for unlimited passwords.'),
                trailing: isPremium 
                  ? const Icon(Icons.check_circle, color: Colors.teal) 
                  : SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: () => context.push('/paywall'),
                        child: const Text('Upgrade'),
                      ),
                    ),
                onTap: isPremium ? null : () => context.push('/paywall'),
              );
            },
          ),
          
          const Divider(height: 32),

          // Danger Zone
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('DANGER ZONE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
          ),
          ListTile(
            title: const Text('Delete All Data', style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Permanently erase all passwords and reset app'),
            trailing: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onTap: _deleteAllData,
          ),
        ],
      ),
    );
  }
}
