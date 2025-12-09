import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme_cicero.dart';
import 'presentation/home_screen.dart';
import 'presentation/login_screen.dart';
import 'presentation/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  await Hive.openBox('chat_history');
  await Hive.openBox('cicero_settings');

  runApp(const ProviderScope(child: CiceroApp()));
}

class CiceroApp extends ConsumerWidget {
  const CiceroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authService = ref.watch(authServiceProvider);
    
    return MaterialApp(
      title: 'Cicero',
      debugShowCheckedModeBanner: false,
      theme: CiceroTheme.light(),
      darkTheme: CiceroTheme.dark(),
      themeMode: themeMode,
      home: StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
