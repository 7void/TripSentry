import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/location_service_helper.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../utils/permission_utils.dart'; // ✅ added import
import '../services/health_connect_service.dart';
import '../services/health_sync_service.dart';
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
      // Health init is best-effort and should not block UX
      try {
        await HealthConnectService.instance.configure();
        await HealthConnectService.instance.requestPlatformPermissions();
        // Request health permissions including background read when supported
        // ignore: unused_result
        await HealthConnectService.instance.requestHealthPermissions(
          withBackground: true,
        );
        // Fire-and-forget sync of latest heart rate to Firestore
        // ignore: discarded_futures
        HealthConnectService.instance.syncLatestHeartRate();
      } catch (_) {}
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
      // Ensure Firestore has blockchainId field for this user (non-blocking for UX)
      // ignore: discarded_futures
      UserService.ensureBlockchainIdOnLogin();
      if (!mounted) return;
      // Navigate immediately — don't block on permissions/service start
      Navigator.of(context).pushReplacementNamed('/home');
      // Kick off tracking initialization in background
      // ignore: discarded_futures
      _initTracking();
  // Start 1-minute health sync loop
  // ignore: discarded_futures
  HealthSyncService.instance.start(interval: const Duration(seconds: 10));
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await AuthService.signInWithGoogle();
      if (user == null) {
        // User cancelled the sign-in flow
        return;
      }
      // Ensure Firestore has blockchainId field for this user (non-blocking for UX)
      // ignore: discarded_futures
      UserService.ensureBlockchainIdOnLogin();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
      // Kick off tracking initialization in background
      // ignore: discarded_futures
      _initTracking();
  // Start 1-minute health sync loop
  // ignore: discarded_futures
  HealthSyncService.instance.start(interval: const Duration(seconds: 10));
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Google sign-in failed: $e';
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
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('or'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _signInWithGoogle,
                icon: const Icon(Icons.account_circle),
                label: const Text('Continue with Google'),
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
