import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme_cicero.dart';
import 'chat_state_notifier.dart';
import 'providers.dart';
import '../services/voice_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final VoiceService _voiceService = VoiceService();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initVoice(); // <--- NEW
  }

  void _initVoice() async {
    await _voiceService.initialize();
  }

  void _toggleListening() {
    if (_isListening) {
      _voiceService.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      _voiceService.startListening(
        onResult: (text) {
          setState(() {
            _controller.text = text;
            // Optional: Auto-send if silence is detected?
            // For now, let's just fill the text box.
          });
        },
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _saveChatToFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final messages = ref.read(chatProvider).messages;
    if (messages.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No messages to save yet.'),
      ));
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now();
      final filename =
          'cicero-chat-${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}-${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}${ts.second.toString().padLeft(2, '0')}.txt';
      final file = File('${dir.path}/$filename');

      final buffer = StringBuffer();
      for (final msg in messages) {
        final speaker = msg.isUser ? 'You' : 'Cicero';
        buffer.writeln('$speaker (${msg.timestamp.toLocal()}):');
        buffer.writeln(msg.content);
        buffer.writeln('---');
      }

      await file.writeAsString(buffer.toString());
      messenger.showSnackBar(SnackBar(
        content: Text('Saved to ${file.path}'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not save chat: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final stateAbbr = ref.watch(selectedStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-scroll on new message
    ref.listen(chatProvider, (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cicero'),
        actions: [
          IconButton(
            tooltip: 'Save chat to device',
            icon: const Icon(LucideIcons.download),
            onPressed: _saveChatToFile,
          ),
          IconButton(
            tooltip: 'Hide keyboard',
            icon: const Icon(Icons.keyboard_hide_outlined),
            onPressed: _hideKeyboard,
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => ref.read(chatProvider.notifier).clearChat(),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _hideKeyboard,
        child: Column(
          children: [
            // MESSAGE LIST
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount:
                    chatState.messages.length + (chatState.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == chatState.messages.length) {
                    return const _LoadingBubble();
                  }
                  final msg = chatState.messages[index];
                  return _MessageBubble(message: msg);
                },
              ),
            ),

            // INPUT AREA
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  // MICROPHONE BUTTON (NEW)
                  GestureDetector(
                    onTap: _toggleListening,
                    child: CircleAvatar(
                      backgroundColor: _isListening
                          ? Colors.red
                          : Colors.grey.shade200,
                      radius: 20,
                      child: Icon(
                        _isListening ? LucideIcons.micOff : LucideIcons.mic,
                        color: _isListening ? Colors.white : Colors.black54,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // TEXT FIELD (EXISTING)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? 'Listening...'
                              : 'Ask a legal question...', // Change hint
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // SEND BUTTON (EXISTING)
                  GestureDetector(
                    onTap: () {
                      if (_controller.text.trim().isNotEmpty) {
                        ref
                            .read(chatProvider.notifier)
                            .sendMessage(_controller.text, stateAbbr);
                        _controller.clear();
                        _hideKeyboard();
                      }
                    },
                    child: CircleAvatar(
                      backgroundColor: CiceroTheme.primaryLight,
                      radius: 20,
                      child: const Icon(
                        LucideIcons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final dynamic message; // ChatMessage type
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 280), // Max bubble width
        decoration: BoxDecoration(
          color: isUser
              ? CiceroTheme.primaryLight
              : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: isUser
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: isUser
            ? Text(
                message.content,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 40,
          height: 20,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }
}
