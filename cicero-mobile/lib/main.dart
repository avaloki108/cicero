import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme_cicero.dart'; // Import the new theme
import 'presentation/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: CiceroApp()));
}

class CiceroApp extends StatelessWidget {
  const CiceroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cicero',
      debugShowCheckedModeBanner: false,
      theme: CiceroTheme.light(),
      darkTheme: CiceroTheme.dark(),
      themeMode: ThemeMode.system, // Auto-switch based on phone settings
      home: const HomeScreen(),
    );
  }
}
