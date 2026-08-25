import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _employeeIdController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _register() async {
    final employeeId = _employeeIdController.text.trim();
    final fullName = _fullNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (employeeId.isEmpty ||
        fullName.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage(
        'Please fill in all fields.',
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage(
        'Passwords do not match.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check whether the employee ID already exists.
      final existingUser = await Supabase.instance.client
          .from('users')
          .select('uid')
          .eq('employee_id', employeeId)
          .maybeSingle();

      if (existingUser != null) {
        if (!mounted) return;

        _showMessage(
          'Employee ID is already registered.',
        );
        return;
      }

      // Convert the password to MD5.
      final passwordHash =
          md5.convert(utf8.encode(password)).toString();

      // Create the user in our users table.
      await Supabase.instance.client
          .from('users')
          .insert({
        'employee_id': employeeId,
        'password': passwordHash,
        'full_name': fullName,
      });

      if (!mounted) return;

      _showMessage(
        'Registration successful. You can now log in.',
      );

      await Future.delayed(
        const Duration(milliseconds: 800),
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Registration failed. '
        'Check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),

              const Icon(
                Icons.person_add_outlined,
                size: 70,
              ),

              const SizedBox(height: 24),

              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Register your employee account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: _employeeIdController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Employee ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.badge_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _fullNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.person_outline,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_isLoading) {
                    _register();
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'REGISTER',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}