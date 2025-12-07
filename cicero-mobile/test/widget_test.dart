import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:cicero_app/main.dart';

void main() {
  late String tempDir;

  setUpAll(() async {
    // Create a temporary directory for Hive in tests
    final directory = await Directory.systemTemp.createTemp('hive_test_');
    tempDir = directory.path;
    
    // Initialize Hive with the temporary directory
    Hive.init(tempDir);
    
    // Open required boxes
    await Hive.openBox('chat_history');
    await Hive.openBox('cicero_settings');
  });

  tearDownAll(() async {
    // Clean up Hive boxes after tests
    await Hive.close();
    
    // Clean up temporary directory
    try {
      await Directory(tempDir).delete(recursive: true);
    } catch (e) {
      // Ignore errors during cleanup
    }
  });

  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CiceroApp()));
    await tester.pumpAndSettle();
    
    // The app title "Cicero" appears in the ChatScreen AppBar
    expect(find.text('Cicero'), findsOneWidget);
  });
}
