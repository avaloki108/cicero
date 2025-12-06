import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/palette.dart';
import '../domain/models/chat_message.dart';
import 'chat_state_notifier.dart';
import 'providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingPrompt = ref.read(promptSelectedProvider);
      if (pendingPrompt != null && pendingPrompt.isNotEmpty) {
        _messageController.text = pendingPrompt;
        ref.read(promptSelectedProvider.notifier).clearPrompt();
        _sendMessage(pendingPrompt);
      } else {
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    final chatState = ref.read(chatProvider);
    if (text.trim().isEmpty || chatState.isLoading) return;

    _messageController.clear();
    final selectedStateAbbr = ref.read(selectedStateProvider);
    await ref.read(chatProvider.notifier).sendMessage(text, selectedStateAbbr);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation?'),
        content: const Text(
            'This will remove all messages from the current session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).clearChat();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _saveChat() {
    final chatState = ref.read(chatProvider);
    if (chatState.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No conversation to save.')),
      );
      return;
    }

    final buffer = StringBuffer()
      ..writeln('Pocket Lawyer Conversation Log')
      ..writeln('Date: ${DateTime.now()}\n');

    for (final msg in chatState.messages) {
      buffer.writeln(
          msg.isUser ? 'You: ${msg.content}' : 'Pocket Lawyer: ${msg.content}');
      if (!msg.isUser && msg.sources != null && msg.sources!.isNotEmpty) {
        buffer.writeln('Sources:');
        for (final source in msg.sources!) {
          buffer.writeln('- ${source.citation}');
        }
      }
      buffer.writeln('-' * 20);
    }

    Share.share(buffer.toString(), subject: 'Pocket Lawyer Conversation');
  }

  @override
  Widget build(BuildContext context) {
    final selectedStateAbbr = ref.watch(selectedStateProvider);
    final selectedStateName = abbrToStateName[selectedStateAbbr] ?? 'Colorado';
    final theme = Theme.of(context);
    final colors = PocketPalette.of(theme.brightness);
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;

    ref.listen<String?>(promptSelectedProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        _messageController.text = next;
        ref.read(promptSelectedProvider.notifier).clearPrompt();
        Future.delayed(const Duration(milliseconds: 100), () {
          _sendMessage(next);
        });
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              colors: colors,
              onNewConversation: _clearChat,
              onSave: _saveChat,
              onClear: _clearChat,
            ),
            const SizedBox(height: 8),
            _LiveStatusBanner(colors: colors),
            const SizedBox(height: 8),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyChatState(
                      colors: colors,
                      selectedStateName: selectedStateName,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      itemCount: messages.length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && isLoading) {
                          return _buildTypingIndicator(colors);
                        }
                        return _buildMessageBubble(messages[index], colors);
                      },
                    ),
            ),
            _InputBar(
              controller: _messageController,
              isLoading: isLoading,
              hintStateName: selectedStateName,
              colors: colors,
              onSend: () => _sendMessage(_messageController.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(PocketColors colors) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          width: 48,
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (i) => _TypingDot(delay: i * 150, colors: colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, PocketColors colors) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? colors.primary : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isUser ? Colors.white : colors.text,
                ),
                a: TextStyle(color: isUser ? Colors.white70 : colors.primary),
              ),
            ),
            if (!isUser &&
                message.sources != null &&
                message.sources!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: colors.border.withAlpha(128)),
              const SizedBox(height: 8),
              Text(
                'Sources:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              ...message.sources!.map(
                (source) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '• ${source.citation}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
            if (message.confidence != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Confidence: ${(message.confidence! * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getConfidenceColor(message.confidence!, colors),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence, PocketColors colors) {
    if (confidence >= 0.8) return colors.success;
    if (confidence >= 0.5) return colors.warning;
    return colors.error;
  }
}

class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay, required this.colors});
  final int delay;
  final PocketColors colors;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.colors.textTertiary
                .withAlpha((128 + 127 * _animation.value).toInt()),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.colors,
    required this.onNewConversation,
    required this.onSave,
    required this.onClear,
  });

  final PocketColors colors;
  final VoidCallback onNewConversation;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pocket Lawyer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, color: colors.text),
            onPressed: onNewConversation,
            tooltip: 'New conversation',
          ),
          IconButton(
            icon: Icon(Icons.ios_share, color: colors.textSecondary, size: 20),
            onPressed: onSave,
            tooltip: 'Share conversation',
          ),
        ],
      ),
    );
  }
}

class _LiveStatusBanner extends StatelessWidget {
  const _LiveStatusBanner({required this.colors});

  final PocketColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.bolt, color: Colors.amber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Direct connection to official law libraries',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Responses include source citations',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const _PulsingLiveIndicator(),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({
    required this.colors,
    required this.selectedStateName,
  });

  final PocketColors colors;
  final String selectedStateName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(Icons.auto_awesome, color: colors.primary, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'How can I help?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about law,\ncontracts, or legal research',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.hintStateName,
    required this.colors,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final String hintStateName;
  final PocketColors colors;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(fontSize: 16, color: colors.text),
                  decoration: InputDecoration(
                    hintText: 'Ask a legal question...',
                    hintStyle: TextStyle(color: colors.placeholder),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  enabled: !isLoading,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isLoading ? null : onSend,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isLoading ? colors.border : colors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: isLoading
                    ? CupertinoActivityIndicator(color: colors.surface)
                    : const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingLiveIndicator extends StatefulWidget {
  const _PulsingLiveIndicator();

  @override
  State<_PulsingLiveIndicator> createState() => _PulsingLiveIndicatorState();
}

class _PulsingLiveIndicatorState extends State<_PulsingLiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}
