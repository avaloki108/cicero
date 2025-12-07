import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/chat_message.dart';
import '../services/cicero_api_client.dart';
import '../services/chat_storage_service.dart';
import 'providers.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  ChatState({this.messages = const [], this.isLoading = false, this.error});

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final CiceroApiClient _apiClient;
  final ChatStorageService _storage = ChatStorageService();

  ChatNotifier(this._apiClient) : super(ChatState()) {
    _loadHistory();
  }

  void _loadHistory() {
    final savedMessages = _storage.loadMessages();
    if (savedMessages.isNotEmpty) {
      state = state.copyWith(messages: savedMessages);
    }
  }

  Future<void> sendMessage(String text, String stateAbbr) async {
    if (text.trim().isEmpty || state.isLoading) return;

    final userMsg = ChatMessage(
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final newMessages = [...state.messages, userMsg];
    state = state.copyWith(messages: newMessages, isLoading: true, error: null);
    _storage.saveMessages(newMessages);

    try {
      // Convert existing messages to history format (excluding the current message being sent)
      final history = newMessages.take(newMessages.length - 1).map((msg) => {
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.content,
      }).toList();

      final response = await _apiClient.sendMessage(text, stateAbbr, history: history);

      String fullContent = response.response;
      if (response.citations.isNotEmpty) {
        fullContent += "\n\nSources:\n${response.citations.join('\n')}";
      }

      final botMsg = ChatMessage(
        content: fullContent,
        isUser: false,
        timestamp: DateTime.now(),
      );

      final finalMessages = [...newMessages, botMsg];
      state = state.copyWith(messages: finalMessages, isLoading: false);
      _storage.saveMessages(finalMessages);
    } catch (e) {
      final errorMsg = ChatMessage(
        content: "Connection error: ${e.toString()}",
        isUser: false,
        timestamp: DateTime.now(),
      );

      final errorMessages = [...newMessages, errorMsg];
      state = state.copyWith(messages: errorMessages, isLoading: false);
      _storage.saveMessages(errorMessages);
    }
  }

  void clearChat() {
    state = ChatState();
    _storage.clearHistory();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final apiClient = ref.watch(ciceroApiClientProvider);
  return ChatNotifier(apiClient);
});
