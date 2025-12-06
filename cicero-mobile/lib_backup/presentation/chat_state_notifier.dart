import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/chat_message.dart';
import '../services/cicero_api_client.dart';
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

  ChatNotifier(this._apiClient) : super(ChatState());

  Future<void> sendMessage(String text, String stateAbbr) async {
    if (text.trim().isEmpty || state.isLoading) return;

    // 1. Show User Message immediately
    final userMsg = ChatMessage(
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      // 2. Call the Python Brain
      final response = await _apiClient.sendMessage(text, stateAbbr);

      // 3. Show Cicero's Response
      // We combine the answer and citations into one readable bubble for now
      String fullContent = response.response;
      if (response.citations.isNotEmpty) {
        fullContent += "\n\nSources:\n${response.citations.join('\n')}";
      }

      final botMsg = ChatMessage(
        content: fullContent,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, botMsg],
        isLoading: false,
      );
    } catch (e) {
      // 4. Handle Errors gracefully
      final errorMsg = ChatMessage(
        content:
            "I'm having trouble connecting to my law library right now. (${e.toString()})",
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
      );
    }
  }

  void clearChat() {
    state = ChatState();
  }
}

// Connect the Notifier to the UI
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final apiClient = ref.watch(ciceroApiClientProvider);
  return ChatNotifier(apiClient);
});
