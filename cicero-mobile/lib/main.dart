import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme_cicero.dart';
import 'presentation/home_screen.dart';
import 'presentation/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return MaterialApp(
      title: 'Cicero',
      debugShowCheckedModeBanner: false,
      theme: CiceroTheme.light(),
      darkTheme: CiceroTheme.dark(),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
