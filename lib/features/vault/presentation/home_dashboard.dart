import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';
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
    _tabController.addListener(() => setState(() {}));
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
    return GradientScaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryCyan.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            if (_tabController.index == 0) {
              context.push('/add-password');
            } else {
              context.push('/add-document');
            }
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.primaryCyan, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'SecureVault',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cloud_download_outlined, color: AppColors.textSecondary),
                    tooltip: 'Restore from Cloud',
                    onPressed: () => context.read<VaultBloc>().add(VaultRestoreFromCloud()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                    onPressed: () => context.push('/settings'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                    onPressed: () => context.read<AuthBloc>().add(AuthLockVault()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search vault...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    fillColor: Colors.transparent,
                    filled: true,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.3)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.key_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Passwords'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_special_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Documents'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Body
            Expanded(
              child: BlocConsumer<VaultBloc, VaultState>(
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
                      SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is VaultLoading || state is VaultInitial) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan));
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
            ),
          ],
        ),
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
      return _buildEmptyState(Icons.key_off_rounded, 'No passwords yet', 'Tap + to add your first password');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        final categoryIndex = ['General', 'Social', 'Work', 'Finance', 'Shopping'].indexOf(entry.category);
        final categoryColor = categoryIndex >= 0 ? AppColors.categoryColors[categoryIndex] : AppColors.primaryCyan;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?',
                    style: TextStyle(color: categoryColor, fontWeight: FontWeight.w700, fontSize: 20),
                  ),
                ),
              ),
              title: Text(
                entry.title,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15),
              ),
              subtitle: Text(
                entry.username,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionIcon(Icons.copy_rounded, () => _copyToClipboard(entry.username, 'Username')),
                  const SizedBox(width: 4),
                  _buildActionIcon(Icons.key_rounded, () => _copyToClipboard(entry.password, 'Password'), color: AppColors.primaryCyan),
                ],
              ),
              onTap: () => context.push('/edit-password', extra: entry),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.textMuted).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
      ),
    );
  }

  Widget _buildDocumentsList(List<DocumentEntry> documents) {
    final filtered = documents.where((d) {
      final query = _searchQuery.toLowerCase();
      return d.title.toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(Icons.folder_off_rounded, 'No documents yet', 'Tap + to save your first document');
    }

    return Column(
      children: [
        // Sync buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Sync'),
                  onPressed: () => context.read<VaultBloc>().add(VaultSyncDocumentsToCloud()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Restore'),
                  onPressed: () => context.read<VaultBloc>().add(VaultRestoreDocumentsFromCloud()),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final entry = filtered[index];
              return GestureDetector(
                onTap: () => context.push('/view-document', extra: entry),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCyan.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.image_rounded, size: 32, color: AppColors.primaryCyan),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.dateAdded.year}-${entry.dateAdded.month.toString().padLeft(2, '0')}-${entry.dateAdded.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textMuted.withValues(alpha: 0.08),
            ),
            child: Icon(icon, size: 56, color: AppColors.textMuted.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}
