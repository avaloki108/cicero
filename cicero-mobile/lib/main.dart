import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme_cicero.dart';
import 'presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('chat_history');

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
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
