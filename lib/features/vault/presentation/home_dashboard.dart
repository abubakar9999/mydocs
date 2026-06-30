import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/vault_bloc.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  String _searchQuery = '';
  Timer? _clipboardTimer;

  @override
  void initState() {
    super.initState();
    // Load passwords when dashboard is opened
    context.read<VaultBloc>().add(VaultLoadPasswords());
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied. Will clear in 30 seconds.')),
    );

    // Auto-clear clipboard after 30 seconds
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard automatically cleared for security.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureVault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              context.push('/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.lock),
            tooltip: 'Lock Vault',
            onPressed: () {
              context.read<AuthBloc>().add(AuthLockVault());
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search vault...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),
        ),
      ),
      body: BlocConsumer<VaultBloc, VaultState>(
        listener: (context, state) {
          if (state is VaultRequiresUpgrade) {
            // Show paywall dialog or navigate to paywall screen
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Upgrade to Premium'),
                content: const Text('You have reached the free limit of 10 items. Upgrade to store unlimited passwords securely.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/paywall');
                    },
                    child: const Text('View Plans'),
                  ),
                ],
              ),
            );
          } else if (state is VaultError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is VaultLoading || state is VaultInitial) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          if (state is VaultLoaded) {
            final passwords = state.passwords.where((p) {
              final query = _searchQuery.toLowerCase();
              return p.title.toLowerCase().contains(query) || 
                     p.username.toLowerCase().contains(query) ||
                     p.category.toLowerCase().contains(query);
            }).toList();

            if (passwords.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text('No passwords found.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // Space for FAB
              itemCount: passwords.length,
              itemBuilder: (context, index) {
                final entry = passwords[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    child: Text(
                      entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?',
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(entry.username),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copy Username',
                        onPressed: () => _copyToClipboard(entry.username, 'Username'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.key, size: 20, color: Colors.teal),
                        tooltip: 'Copy Password',
                        onPressed: () => _copyToClipboard(entry.password, 'Password'),
                      ),
                    ],
                  ),
                  onTap: () {
                    context.push('/edit-password', extra: entry);
                  },
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/add-password');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
