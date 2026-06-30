import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _passwordController.dispose();
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
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_person, size: 80, color: Colors.teal),
                    const SizedBox(height: 32),
                    const Text(
                      'Unlock SecureVault',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 48),
                    
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscureText,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Master Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Unlock Vault'),
                    ),
                    
                    if (canUseBiometrics) ...[
                      const SizedBox(height: 32),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('OR', style: TextStyle(color: Colors.grey)),
                          ),
                          Expanded(child: Divider(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      IconButton(
                        iconSize: 64,
                        color: Colors.teal,
                        icon: const Icon(Icons.fingerprint),
                        onPressed: isLoading ? null : _useBiometrics,
                      ),
                      const Text(
                        'Use Biometrics',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                      )
                    ]
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
