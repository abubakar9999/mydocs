import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../shared/theme/app_theme.dart';
import '../bloc/vault_bloc.dart';
import '../data/document_entry.dart';

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({super.key});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  XFile? _selectedImage;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() => _selectedImage = picked);
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate() || _selectedImage == null) return;

    setState(() => _isSaving = true);

    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        _selectedImage!.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
      );

      if (compressedBytes == null) throw Exception('Image compression failed');

      final id = const Uuid().v4();
      final docsDir = await getApplicationDocumentsDirectory();
      final filePath = '${docsDir.path}/doc_$id.enc';

      final entry = DocumentEntry(
        id: id,
        title: _titleController.text.trim(),
        localFilePath: filePath,
        dateAdded: DateTime.now(),
      );

      if (mounted) {
        context.read<VaultBloc>().add(VaultAddDocument(entry, compressedBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document saved successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving document: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Add Document')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GlassContainer(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Document Title (e.g. NID Front)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter a title';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Image picker area
                    if (_selectedImage != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_selectedImage!.path),
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.bgDark.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: AppColors.error, size: 20),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      // Dashed border picker
                      GestureDetector(
                        onTap: () => _pickImage(ImageSource.gallery),
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.glassBorder, width: 2),
                            color: AppColors.bgDark.withValues(alpha: 0.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryCyan.withValues(alpha: 0.1),
                                ),
                                child: const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.primaryCyan),
                              ),
                              const SizedBox(height: 12),
                              const Text('Tap to select an image', style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              const Text('or use the buttons below', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Camera / Gallery buttons
                    if (_selectedImage == null)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Camera'),
                              onPressed: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                              onPressed: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
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
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.lock_rounded, color: Colors.white),
                  label: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Encrypt & Save', style: TextStyle(color: Colors.white)),
                  onPressed: _isSaving ? null : _saveDocument,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
