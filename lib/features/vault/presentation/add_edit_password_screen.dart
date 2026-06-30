// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Password' : 'Add Password'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Password'),
                    content: const Text('Are you sure you want to delete this entry?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _delete();
                        },
                        child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
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
            padding: const EdgeInsets.all(16.0),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title (e.g. Google, Netflix)', prefixIcon: Icon(Icons.title)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username or Email', prefixIcon: Icon(Icons.person)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.generating_tokens, color: Colors.teal),
                        onPressed: _openGenerator,
                        tooltip: 'Generate Password',
                      ),
                      IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ],
                  ),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(labelText: 'URL (optional)', prefixIcon: Icon(Icons.link)),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.folder)),
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.note)),
                maxLines: 3,
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
