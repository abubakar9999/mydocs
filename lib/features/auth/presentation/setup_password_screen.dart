import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  // Basic strength indicator logic
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
    if (score <= 0.25) return Colors.red;
    if (score <= 0.5) return Colors.orange;
    if (score <= 0.75) return Colors.yellow;
    return Colors.green;
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

    // Trigger BLoC event
    context.read<AuthBloc>().add(AuthSetupMasterPassword(_emailController.text.trim(), _password));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Master Password'),
      ),
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

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.key, size: 80, color: Colors.teal),
                  const SizedBox(height: 24),
                  const Text(
                    'Create your Master Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This is the only key that can decrypt your vault. If you lose it, your data cannot be recovered.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  
                  // Email Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText1,
                    onChanged: (val) {
                      setState(() {
                        _password = val;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Master Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText1 ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _obscureText1 = !_obscureText1;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Strength Indicator
                  if (_password.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _strengthScore,
                              backgroundColor: Colors.grey[800],
                              color: _strengthColor,
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _strengthText,
                          style: TextStyle(color: _strengthColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    
                  const SizedBox(height: 24),
                  
                  // Confirm Password Field
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureText2,
                    decoration: InputDecoration(
                      labelText: 'Confirm Master Password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText2 ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _obscureText2 = !_obscureText2;
                          });
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading 
                        ? const SizedBox(
                            width: 24, height: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Text('Confirm & Save'),
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
