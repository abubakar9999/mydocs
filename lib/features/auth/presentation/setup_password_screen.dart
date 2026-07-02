import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';

class SetupPasswordScreen extends StatefulWidget {
  const SetupPasswordScreen({super.key});

  @override
  State<SetupPasswordScreen> createState() => _SetupPasswordScreenState();
}

class _SetupPasswordScreenState extends State<SetupPasswordScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureText1 = true;
  bool _obscureText2 = true;
  String _password = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  double get _strengthScore {
    if (_password.isEmpty) return 0;
    double score = 0;
    if (_password.length >= 8) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(_password)) score += 0.25;
    if (RegExp(r'[0-9]').hasMatch(_password)) score += 0.25;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(_password)) score += 0.25;
    return score;
  }

  Color get _strengthColor {
    final score = _strengthScore;
    if (score <= 0.25) return AppColors.error;
    if (score <= 0.5) return AppColors.warning;
    if (score <= 0.75) return AppColors.accentAmber;
    return AppColors.success;
  }

  String get _strengthText {
    final score = _strengthScore;
    if (score == 0) return '';
    if (score <= 0.25) return 'Weak';
    if (score <= 0.5) return 'Fair';
    if (score <= 0.75) return 'Good';
    return 'Strong';
  }

  void _submit() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    if (_password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password cannot be empty')),
      );
      return;
    }
    if (_password != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    if (_strengthScore < 0.5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a stronger password')),
      );
      return;
    }
    context.read<AuthBloc>().add(AuthSetupMasterPassword(_emailController.text.trim(), _password));
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Setup Master Password'),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Header icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryCyan.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCyan.withValues(alpha: 0.2),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.key_rounded, size: 56, color: AppColors.primaryCyan),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create Your Master Key',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Warning callout
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This is the only key that can decrypt your vault. If you lose it, your data cannot be recovered.',
                            style: TextStyle(color: AppColors.warning.withValues(alpha: 0.9), fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form
                  GlassContainer(
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscureText1,
                          onChanged: (val) => setState(() => _password = val),
                          decoration: InputDecoration(
                            labelText: 'Master Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureText1 ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureText1 = !_obscureText1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Strength indicator
                        if (_password.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: _strengthScore,
                                    backgroundColor: AppColors.bgDark,
                                    color: _strengthColor,
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _strengthText,
                                style: TextStyle(color: _strengthColor, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureText2,
                          decoration: InputDecoration(
                            labelText: 'Confirm Master Password',
                            prefixIcon: const Icon(Icons.lock_reset_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureText2 ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureText2 = !_obscureText2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

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
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Confirm & Save', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
