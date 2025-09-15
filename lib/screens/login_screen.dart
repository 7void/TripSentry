import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/location_service_helper.dart';
import '../utils/permission_utils.dart'; // ✅ added import
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _initTracking() async {
    try {
      final granted = await PermissionUtils.requestLocationPermissions();
      if (granted) {
        await LocationServiceHelper.startServiceIfAllowed();
      }
    } catch (_) {
      // Swallow errors to avoid blocking login UX
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Navigate immediately — don't block on permissions/service start
      Navigator.of(context).pushReplacementNamed('/home');
      // Kick off tracking initialization in background
      // ignore: discarded_futures
      _initTracking();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Sign-in failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading
                  ? null
                  : () =>
                      Navigator.of(context).pushReplacementNamed('/register'),
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
