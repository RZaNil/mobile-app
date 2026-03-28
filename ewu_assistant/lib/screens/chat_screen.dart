import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/student_profile.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.onSignedOut});

  final Future<void> Function() onSignedOut;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _lastMessageCount = 0;

  static const List<String> _defaultSuggestions = <String>[
    'Tell me about EWU admission',
    'What clubs can I join?',
    'How much is tuition?',
    'Where is the campus?',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(ChatProvider provider) {
    final String text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _messageController.clear();
    provider.sendMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      if (_scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (BuildContext context, ChatProvider provider, Widget? child) {
        if (provider.messages.length != _lastMessageCount || provider.loading) {
          _lastMessageCount = provider.messages.length;
          _scrollToBottom();
        }

        final ChatMessage? latestReply = _latestAssistantMessage(
          provider.messages,
        );
        final List<String> suggestions =
            latestReply?.suggestions.isNotEmpty == true
            ? latestReply!.suggestions
            : _defaultSuggestions;
        final StudentProfile? profile = provider.studentProfile;

        return Scaffold(
          appBar: AppBar(
            title: const Text('EWU Assistant'),
            actions: <Widget>[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: provider.serverOnline
                            ? AppTheme.success
                            : const Color(0xFFFFD166),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.serverOnline ? 'Online' : 'Offline fallback',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: provider.messages.isEmpty
                    ? null
                    : provider.clearMessages,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Clear chat',
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<ProfileScreen>(
                      builder: (_) =>
                          ProfileScreen(onSignedOut: widget.onSignedOut),
                    ),
                  );
                },
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  backgroundImage: profile?.photoUrl.isNotEmpty == true
                      ? NetworkImage(profile!.photoUrl)
                      : null,
                  child: profile?.photoUrl.isEmpty != false
                      ? Text(
                          (profile?.firstName ?? 'E')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                child: provider.messages.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            provider.messages.length +
                            (provider.loading ? 1 : 0),
                        itemBuilder: (BuildContext context, int index) {
                          if (index >= provider.messages.length) {
                            return const _TypingIndicator();
                          }
                          final ChatMessage message = provider.messages[index];
                          return _ChatBubble(message: message);
                        },
                      ),
              ),
              if (provider.messages.isNotEmpty) ...<Widget>[
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (BuildContext context, int index) {
                      final String suggestion = suggestions[index];
                      return ActionChip(
                        label: Text(suggestion),
                        onPressed: () => provider.sendMessage(suggestion),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(width: 8),
                    itemCount: suggestions.length,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textInputAction: TextInputAction.send,
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: (_) => _send(provider),
                          decoration: const InputDecoration(
                            hintText: 'Ask about EWU...',
                            prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: provider.loading
                            ? null
                            : () => _send(provider),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 92,
              width: 92,
              decoration: BoxDecoration(
                color: AppTheme.botBubble,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 42,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chat with EWU Assistant',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask about admissions, courses, fees, clubs, or any campus topic you need help with.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _defaultSuggestions
                  .map(
                    (String suggestion) => ActionChip(
                      label: Text(suggestion),
                      onPressed: () {
                        context.read<ChatProvider>().sendMessage(suggestion);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  ChatMessage? _latestAssistantMessage(List<ChatMessage> messages) {
    for (final ChatMessage message in messages.reversed) {
      if (!message.isUser) {
        return message;
      }
    }
    return null;
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;
    final Color bubbleColor = isUser ? AppTheme.userBubble : AppTheme.botBubble;
    final Color textColor = isUser ? Colors.white : AppTheme.textPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.text,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: textColor, height: 1.45),
            ),
            if (!isUser &&
                (message.intent != null ||
                    message.source != null ||
                    message.responseTimeMs != null)) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (message.intent != null)
                    _MetaChip(label: message.intent!.replaceAll('_', ' ')),
                  if (message.source != null) _MetaChip(label: message.source!),
                  if (message.responseTimeMs != null)
                    _MetaChip(
                      label: '${message.responseTimeMs!.toStringAsFixed(0)} ms',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.botBubble,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 12),
            Text(
              'Thinking...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
