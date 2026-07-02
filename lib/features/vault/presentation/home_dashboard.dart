import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/vault_bloc.dart';
import '../data/vault_repository.dart';
import '../data/document_entry.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  Timer? _clipboardTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load data when dashboard is opened
    context.read<VaultBloc>().add(VaultLoadData());
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied. Will clear in 30 seconds.')),
    );

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
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Restore from Online',
            onPressed: () {
              context.read<VaultBloc>().add(VaultRestoreFromCloud());
            },
          ),
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
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Passwords', icon: Icon(Icons.password)),
                  Tab(text: 'Documents', icon: Icon(Icons.folder_special)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: BlocConsumer<VaultBloc, VaultState>(
        listener: (context, state) {
          if (state is VaultRequiresUpgrade) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Upgrade to Premium'),
                content: Text(state.message),
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
            return TabBarView(
              controller: _tabController,
              children: [
                _buildPasswordsList(state.passwords),
                _buildDocumentsList(state.documents),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            context.push('/add-password');
          } else {
            context.push('/add-document');
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPasswordsList(List<PasswordEntry> passwords) {
    final filtered = passwords.where((p) {
      final query = _searchQuery.toLowerCase();
      return p.title.toLowerCase().contains(query) || 
             p.username.toLowerCase().contains(query) ||
             p.category.toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No passwords found.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
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
                onPressed: () => _copyToClipboard(entry.username, 'Username'),
              ),
              IconButton(
                icon: const Icon(Icons.key, size: 20, color: Colors.teal),
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

  Widget _buildDocumentsList(List<DocumentEntry> documents) {
    final filtered = documents.where((d) {
      final query = _searchQuery.toLowerCase();
      return d.title.toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No documents found.', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        // Cloud sync buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Sync to Cloud'),
                  onPressed: () {
                    context.read<VaultBloc>().add(VaultSyncDocumentsToCloud());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text('Restore'),
                  onPressed: () {
                    context.read<VaultBloc>().add(VaultRestoreDocumentsFromCloud());
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8).copyWith(bottom: 80),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final entry = filtered[index];
              return InkWell(
                onTap: () {
                  context.push('/view-document', extra: entry);
                },
                child: Card(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image, size: 48, color: Colors.teal),
                      const SizedBox(height: 8),
                      Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.dateAdded.year}-${entry.dateAdded.month.toString().padLeft(2, '0')}-${entry.dateAdded.day.toString().padLeft(2, '0')}', 
                        style: const TextStyle(fontSize: 12, color: Colors.grey)
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
