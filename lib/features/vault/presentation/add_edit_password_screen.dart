// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/theme/app_theme.dart';
import '../bloc/vault_bloc.dart';
import '../data/vault_repository.dart';
import '../../generator/presentation/password_generator_sheet.dart';

class AddEditPasswordScreen extends StatefulWidget {
  final PasswordEntry? existingEntry;

  const AddEditPasswordScreen({super.key, this.existingEntry});

  @override
  State<AddEditPasswordScreen> createState() => _AddEditPasswordScreenState();
}

class _AddEditPasswordScreenState extends State<AddEditPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _notesCtrl;

  String _category = 'General';
  bool _obscurePassword = true;

  final List<String> _categories = ['General', 'Social', 'Work', 'Finance', 'Shopping'];

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;
    _titleCtrl = TextEditingController(text: entry?.title ?? '');
    _usernameCtrl = TextEditingController(text: entry?.username ?? '');
    _passwordCtrl = TextEditingController(text: entry?.password ?? '');
    _urlCtrl = TextEditingController(text: entry?.url ?? '');
    _notesCtrl = TextEditingController(text: entry?.notes ?? '');
    if (entry != null && _categories.contains(entry.category)) {
      _category = entry.category;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final isEditing = widget.existingEntry != null;
      final entry = PasswordEntry(
        id: isEditing ? widget.existingEntry!.id : const Uuid().v4(),
        title: _titleCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        url: _urlCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        category: _category,
      );

      if (isEditing) {
        context.read<VaultBloc>().add(VaultUpdatePassword(entry));
      } else {
        context.read<VaultBloc>().add(VaultAddPassword(entry));
      }
      context.pop();
    }
  }

  void _delete() {
    if (widget.existingEntry != null) {
      context.read<VaultBloc>().add(VaultDeletePassword(widget.existingEntry!.id));
      context.pop();
    }
  }

  void _openGenerator() {
    PasswordGeneratorSheet.show(context, (generatedPassword) {
      setState(() {
        _passwordCtrl.text = generatedPassword;
        _obscurePassword = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingEntry != null;

    return GradientScaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Password' : 'Add Password'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              onPressed: () {
                showModalBottomSheet(
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
                          child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text('Delete Password?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        const Text('This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _delete();
                                },
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title (e.g. Google, Netflix)', prefixIcon: Icon(Icons.title_rounded)),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(labelText: 'Username or Email', prefixIcon: Icon(Icons.person_outline_rounded)),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.accentAmber),
                              onPressed: _openGenerator,
                              tooltip: 'Generate Password',
                            ),
                            IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ],
                        ),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CATEGORY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.asMap().entries.map((e) {
                        final isSelected = _category == e.value;
                        final color = AppColors.categoryColors[e.key];
                        return GestureDetector(
                          onTap: () => setState(() => _category = e.value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.15) : AppColors.bgDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : AppColors.glassBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              e.value,
                              style: TextStyle(
                                color: isSelected ? color : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OPTIONAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(labelText: 'URL', prefixIcon: Icon(Icons.link_rounded)),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.note_outlined)),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCyan.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  onPressed: _save,
                  child: const Text('Save Password', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
