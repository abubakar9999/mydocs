import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _submit() {
    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your master password')),
      );
      return;
    }
    context.read<AuthBloc>().add(AuthLoginWithPassword(pwd));
  }

  void _useBiometrics() {
    context.read<AuthBloc>().add(AuthLoginWithBiometrics());
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
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
          bool canUseBiometrics = false;

          if (state is AuthLocked) {
            canUseBiometrics = state.canUseBiometrics;
          }

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated glowing shield icon
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryCyan.withValues(alpha: 0.08),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCyan.withValues(alpha: _glowAnimation.value),
                                blurRadius: 50,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.shield_outlined, size: 64, color: AppColors.primaryCyan),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your master password to unlock',
                      style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 40),

                    // Glass card form
                    GlassContainer(
                      child: Column(
                        children: [
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscureText,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Master Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureText = !_obscureText),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Gradient unlock button
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
                                  : const Text('Unlock Vault', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (canUseBiometrics) ...[
                      const SizedBox(height: 36),
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.glassBorder)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('OR', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          ),
                          Expanded(child: Divider(color: AppColors.glassBorder)),
                        ],
                      ),
                      const SizedBox(height: 36),
                      // Biometric glass button
                      GestureDetector(
                        onTap: isLoading ? null : _useBiometrics,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.bgCard,
                            border: Border.all(color: AppColors.glassBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCyan.withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.fingerprint, size: 48, color: AppColors.primaryCyan),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Use Biometrics',
                        style: TextStyle(
                          color: AppColors.primaryCyan,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
