import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/chat_message.dart';

class ChatStorageService {
  final Box _box = Hive.box('chat_history');

  Future<void> saveMessages(List<ChatMessage> messages) async {
    final data = messages.map((m) => {
      'content': m.content,
      'isUser': m.isUser,
      'timestamp': m.timestamp.toIso8601String(),
    }).toList();
    
    await _box.put('current_session', data);
  }

  List<ChatMessage> loadMessages() {
    final data = _box.get('current_session');
    
    if (data == null) return [];

    return (data as List).map((item) {
      final map = Map<String, dynamic>.from(item);
      return ChatMessage(
        content: map['content'],
        isUser: map['isUser'],
        timestamp: DateTime.parse(map['timestamp']),
      );
    }).toList();
  }

  Future<void> clearHistory() async {
    await _box.delete('current_session');
  }
}
