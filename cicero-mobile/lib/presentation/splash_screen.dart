import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/biometric_service.dart';
import 'providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAuth();
  }

  /// Navigates to the home screen or auth screen after a delay.
  Future<void> _navigateNext() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    // 500ms delay
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    authState.when(
      data: (user) {
        if (user != null) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/auth');
        }
      },
      loading: () {
        // If loading, wait a bit and retry (or listen to changes)
        // For simplicity, we'll just wait a bit more or default to auth
        // Better approach: Watch in build, but here we are in async method.
        // Let's just push /auth and let AuthScreen handle state or redirect?
        // No, let's wait for stream.
        Navigator.of(context).pushReplacementNamed('/auth');
      },
      error: (_, __) => Navigator.of(context).pushReplacementNamed('/auth'),
    );
  }

  Future<void> _checkBiometricAuth() async {
    final disableBiometric = (dotenv.maybeGet('DISABLE_BIOMETRIC') ??
                const String.fromEnvironment('DISABLE_BIOMETRIC',
                    defaultValue: 'false'))
            .toLowerCase() ==
        'true';
    if (disableBiometric) {
      await _navigateNext();
      return;
    }

    final isAvailable = await _biometricService.isBiometricAvailable();

    if (isAvailable) {
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Authenticate to access Pocket Lawyer',
      );

      if (authenticated) {
        await _navigateNext();
      } else {
        _showAuthFailedDialog();
      }
    } else {
      await _navigateNext();
    }
  }

  void _showAuthFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: const Text('Unable to authenticate. Please try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkBiometricAuth();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 200,
          height: 200,
        ),
      ),
    );
  }
}
