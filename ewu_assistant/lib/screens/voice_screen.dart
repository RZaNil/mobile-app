import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/student_profile.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_branding.dart';
import '../widgets/app_confirmation_dialog.dart';
import 'profile_screen.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key, required this.onSignedOut});

  final Future<void> Function() onSignedOut;

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  late final AnimationController _voicePulseController;

  int _lastRenderedMessageCount = -1;

  @override
  void initState() {
    super.initState();
    _voicePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _voicePulseController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncAnimations(ChatProvider provider) {
    if (provider.listening && !_voicePulseController.isAnimating) {
      _voicePulseController.repeat();
    } else if (!provider.listening && _voicePulseController.isAnimating) {
      _voicePulseController.stop();
      _voicePulseController.reset();
    }
  }

  void _scheduleScroll(List<ChatMessage> messages, bool loading) {
    final int targetCount = messages.length + (loading ? 1 : 0);
    if (targetCount == _lastRenderedMessageCount) {
      return;
    }

    _lastRenderedMessageCount = targetCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleVoiceTap(ChatProvider provider) async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (provider.loading) {
      _showMessage('Please wait for the current reply to finish first.');
      return;
    }

    if (provider.listening) {
      await provider.stopListening();
      return;
    }

    final bool started = await provider.startListening();
    if (!started) {
      final String message =
          provider.voiceErrorMessage ??
          'Microphone access or speech recognition is unavailable right now. Check mic permission and try again.';

      if (!mounted) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          action: provider.voicePermissionBlocked
              ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
              : null,
        ),
      );
    }
  }

  Future<void> _send(ChatProvider provider, [String? preset]) async {
    final String text = (preset ?? _messageController.text).trim();
    if (text.isEmpty || provider.loading) {
      return;
    }

    if (provider.listening) {
      await provider.stopListening();
    }

    if (preset == null) {
      _messageController.clear();
    }

    await provider.sendMessage(text);
    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _messageFocusNode.requestFocus();
      }
    });
  }

  Future<void> _confirmClear(ChatProvider provider) async {
    final bool confirmed = await showAppConfirmationDialog(
      context,
      title: 'Clear Assistant Session?',
      message:
          'This will remove your current assistant conversation and reset the voice session.',
      confirmLabel: 'Clear Session',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    provider.clearMessages();
    _messageController.clear();
    _showMessage('Assistant session cleared.');
  }

  ChatMessage? _latestAssistantMessage(List<ChatMessage> messages) {
    for (final ChatMessage message in messages.reversed) {
      if (!message.isUser) {
        return message;
      }
    }
    return null;
  }

  ChatMessage? _latestUserMessage(List<ChatMessage> messages) {
    for (final ChatMessage message in messages.reversed) {
      if (message.isUser) {
        return message;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (BuildContext context, ChatProvider provider, Widget? child) {
        final List<ChatMessage> messages = provider.messages;
        final ChatMessage? latestReply = _latestAssistantMessage(messages);
        final ChatMessage? latestUser = _latestUserMessage(messages);
        final _PromptSuggestionSet promptSet = _AssistantPromptEngine.build(
          latestUser: latestUser,
          latestReply: latestReply,
        );
        final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final double pageBottomInset = keyboardInset > 0 ? keyboardInset + 10 : 6;
        final double navSpacing = keyboardInset > 0 ? 0 : 18;

        _syncAnimations(provider);
        _scheduleScroll(messages, provider.loading);

        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: const Color(0xFFF8FBFF),
            body: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFFFCFDFF), Color(0xFFF2F7FF)],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: -80,
                  right: -50,
                  child: _BackgroundGlow(size: 230, color: Color(0x160A1F44)),
                ),
                Positioned(
                  top: 160,
                  left: -80,
                  child: _BackgroundGlow(
                    size: 250,
                    color: AppTheme.primaryLight.withValues(alpha: 0.08),
                  ),
                ),
                SafeArea(
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.fromLTRB(20, 12, 20, pageBottomInset),
                    child: Column(
                      children: <Widget>[
                        _AssistantTopBar(
                          profile: provider.studentProfile,
                          serverOnline: provider.serverOnline,
                          hasMessages: messages.isNotEmpty,
                          onOpenProfile: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<ProfileScreen>(
                                builder: (_) => ProfileScreen(
                                  onSignedOut: widget.onSignedOut,
                                ),
                              ),
                            );
                          },
                          onClear: () => _confirmClear(provider),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: messages.isEmpty && !provider.loading
                              ? _IdleAssistantState(
                                  provider: provider,
                                  profile: provider.studentProfile,
                                  promptSet: promptSet,
                                  pulseController: _voicePulseController,
                                  onPromptTap: (String prompt) =>
                                      _send(provider, prompt),
                                  onVoiceTap: () => _handleVoiceTap(provider),
                                )
                              : _ConversationState(
                                  messages: messages,
                                  loading: provider.loading,
                                  partialText: provider.partialText,
                                  scrollController: _scrollController,
                                ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: navSpacing),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const SizedBox(height: 8),
                              if (messages.isNotEmpty || provider.loading)
                                _InlinePromptStrip(
                                  prompts: promptSet.prompts.take(4).toList(),
                                  onPromptTap: provider.loading
                                      ? null
                                      : (String prompt) =>
                                            _send(provider, prompt),
                                ),
                              if (messages.isNotEmpty || provider.loading)
                                const SizedBox(height: 8),
                              _AssistantComposer(
                                controller: _messageController,
                                focusNode: _messageFocusNode,
                                loading: provider.loading,
                                listening: provider.listening,
                                onSend: () => _send(provider),
                                onVoiceTap: () => _handleVoiceTap(provider),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssistantTopBar extends StatelessWidget {
  const _AssistantTopBar({
    required this.profile,
    required this.serverOnline,
    required this.hasMessages,
    required this.onOpenProfile,
    required this.onClear,
  });

  final StudentProfile? profile;
  final bool serverOnline;
  final bool hasMessages;
  final VoidCallback onOpenProfile;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        AppLogoMark(
          size: 40,
          framed: true,
          backgroundColor: const Color(0xFFEAF2FF),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'EWU Assistant',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Container(
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: serverOnline
                          ? const Color(0xFF58C97A)
                          : const Color(0xFFFFC857),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      serverOnline
                          ? 'EWU Assistant is online'
                          : 'Using fallback response mode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: hasMessages ? onClear : null,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF1F5FB),
            foregroundColor: AppTheme.primaryDark,
          ),
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onOpenProfile,
          borderRadius: BorderRadius.circular(999),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEAF2FF),
            backgroundImage: profile?.photoUrl.isNotEmpty == true
                ? NetworkImage(profile!.photoUrl)
                : null,
            child: profile?.photoUrl.isEmpty != false
                ? Text(
                    (profile?.firstName ?? 'E').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _IdleAssistantState extends StatelessWidget {
  const _IdleAssistantState({
    required this.provider,
    required this.profile,
    required this.promptSet,
    required this.pulseController,
    required this.onPromptTap,
    required this.onVoiceTap,
  });

  final ChatProvider provider;
  final StudentProfile? profile;
  final _PromptSuggestionSet promptSet;
  final AnimationController pulseController;
  final ValueChanged<String> onPromptTap;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    final String title = provider.listening ? 'Listening...' : 'Need anything?';
    final String subtitle = provider.partialText.trim().isNotEmpty
        ? provider.partialText.trim()
        : profile == null
        ? 'EWU Assistant helps you find campus information faster and more clearly.'
        : 'Hello, ${profile!.firstName}. Ask about admission, tuition, faculty, routine, or student life.';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _AssistantOrb(
                      listening: provider.listening,
                      loading: provider.loading,
                      pulseController: pulseController,
                      onTap: onVoiceTap,
                    ),
                    const SizedBox(height: 26),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: promptSet.prompts.take(6).map((String prompt) {
                        return _QuickPromptChip(
                          label: prompt,
                          onTap: () => onPromptTap(prompt),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConversationState extends StatelessWidget {
  const _ConversationState({
    required this.messages,
    required this.loading,
    required this.partialText,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final bool loading;
  final String partialText;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      itemCount:
          messages.length +
          (loading ? 1 : 0) +
          (partialText.trim().isNotEmpty ? 1 : 0),
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        if (index < messages.length) {
          return _ConversationBubble(message: messages[index]);
        }

        final bool showTyping = loading;
        final int loadingIndex = messages.length;

        if (showTyping && index == loadingIndex) {
          return const _TypingBubble();
        }

        return _ListeningBubble(text: partialText.trim());
      },
    );
  }
}

class _AssistantOrb extends StatelessWidget {
  const _AssistantOrb({
    required this.listening,
    required this.loading,
    required this.pulseController,
    required this.onTap,
  });

  final bool listening;
  final bool loading;
  final AnimationController pulseController;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (BuildContext context, Widget? child) {
        final double pulse = listening
            ? 0.5 + (math.sin(pulseController.value * math.pi * 2) * 0.5)
            : 0;

        return SizedBox(
          height: 170,
          width: 170,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                height: 170,
                width: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppTheme.primaryLight.withValues(
                        alpha: 0.10 + pulse * 0.10,
                      ),
                      AppTheme.primaryLight.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                height: 124,
                width: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFFFFFFFF), Color(0xFFE3EEFF)],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppTheme.primaryLight.withValues(
                        alpha: listening ? 0.28 : 0.14,
                      ),
                      blurRadius: listening ? 28 : 18,
                      spreadRadius: listening ? 6 : 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: Icon(
                      listening
                          ? Icons.graphic_eq_rounded
                          : loading
                          ? Icons.auto_awesome_rounded
                          : Icons.mic_none_rounded,
                      size: 42,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: <Color>[color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _ConversationBubble extends StatelessWidget {
  const _ConversationBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;
    final Alignment alignment = isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final double maxWidth = MediaQuery.sizeOf(context).width * 0.74;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth > 340 ? 340 : maxWidth),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF7B66FF), Color(0xFF5C8DFF)],
                  )
                : null,
            color: isUser ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 8),
              bottomRight: Radius.circular(isUser ? 8 : 20),
            ),
            boxShadow: isUser
                ? const <BoxShadow>[]
                : const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x100A1F44),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!isUser) ...<Widget>[
                Text(
                  'EWU Assistant',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  height: 1.45,
                ),
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
                      _MiniMetaChip(
                        label: message.intent!.replaceAll('_', ' '),
                      ),
                    if (message.source != null)
                      _MiniMetaChip(label: message.source!),
                    if (message.responseTimeMs != null)
                      _MiniMetaChip(
                        label:
                            '${message.responseTimeMs!.toStringAsFixed(0)} ms',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ListeningBubble extends StatelessWidget {
  const _ListeningBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F6FE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Listening...',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x100A1F44),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (int index) {
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
              child: Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.34),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _InlinePromptStrip extends StatelessWidget {
  const _InlinePromptStrip({required this.prompts, required this.onPromptTap});

  final List<String> prompts;
  final ValueChanged<String>? onPromptTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: prompts.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String prompt = prompts[index];
          return _QuickPromptChip(
            label: prompt,
            compact: true,
            onTap: onPromptTap == null ? null : () => onPromptTap!(prompt),
          );
        },
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({
    required this.label,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: compact ? Colors.white : const Color(0xFFF5F8FD),
      borderRadius: BorderRadius.circular(compact ? 16 : 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 10 : 11,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantComposer extends StatelessWidget {
  const _AssistantComposer({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.listening,
    required this.onSend,
    required this.onVoiceTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final bool listening;
  final VoidCallback onSend;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x120A1F44),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Ask anything...',
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder:
                      (
                        BuildContext context,
                        TextEditingValue value,
                        Widget? child,
                      ) {
                        final bool hasText = value.text.trim().isNotEmpty;
                        return SizedBox(
                          height: 42,
                          width: 42,
                          child: FilledButton(
                            onPressed: loading || !hasText ? null : onSend,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7B66FF),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: loading && hasText
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward_rounded),
                          ),
                        );
                      },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF8D7BFF), Color(0xFF5C8DFF)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(
                  0xFF7B66FF,
                ).withValues(alpha: listening ? 0.30 : 0.18),
                blurRadius: listening ? 22 : 14,
                spreadRadius: listening ? 4 : 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onVoiceTap,
              child: Icon(
                listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMetaChip extends StatelessWidget {
  const _MiniMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FE),
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

class _PromptSuggestionSet {
  const _PromptSuggestionSet({required this.prompts});

  final List<String> prompts;
}

class _AssistantPromptEngine {
  const _AssistantPromptEngine._();

  static const List<String> _defaultPrompts = <String>[
    'Admission requirements',
    'Tuition fees',
    'Campus facilities',
    'Student clubs',
    'Faculty contacts',
    'Grading system',
  ];

  static const Map<String, List<String>> _topicPrompts = <String, List<String>>{
    'tuition': <String>[
      'Credit fees',
      'Payment policy',
      'Scholarships',
      'Graduate tuition',
    ],
    'admission': <String>[
      'Required documents',
      'Application deadline',
      'Admission test',
      'Waiver info',
    ],
    'faculty': <String>[
      'Office room',
      'Email address',
      'Office hours',
      'Department contact',
    ],
    'routine': <String>[
      'Prerequisites',
      'Similar courses',
      'Credit hours',
      'Lab sections',
    ],
    'campus': <String>[
      'Library facilities',
      'Transport support',
      'Sports and clubs',
      'Campus food court',
    ],
    'grading': <String>[
      'CGPA scale',
      'Retake policy',
      'Marks distribution',
      'Academic warning',
    ],
  };

  static _PromptSuggestionSet build({
    required ChatMessage? latestUser,
    required ChatMessage? latestReply,
  }) {
    final List<String> backendSuggestions = _clean(
      latestReply?.suggestions ?? const <String>[],
    );

    if (latestUser == null && backendSuggestions.isEmpty) {
      return const _PromptSuggestionSet(prompts: _defaultPrompts);
    }

    final String context = <String>[
      latestUser?.text ?? '',
      latestReply?.intent ?? '',
      latestReply?.text ?? '',
    ].join(' ').toLowerCase();

    final String topic = _detectTopic(context);
    final List<String> prompts = <String>[
      ...backendSuggestions,
      ...?(_topicPrompts[topic]),
    ];

    final List<String> cleaned = _clean(prompts);
    return _PromptSuggestionSet(
      prompts: cleaned.isEmpty ? _defaultPrompts : cleaned.take(6).toList(),
    );
  }

  static String _detectTopic(String source) {
    if (_containsAny(source, <String>[
      'tuition',
      'fee',
      'fees',
      'scholarship',
      'payment',
      'waiver',
    ])) {
      return 'tuition';
    }
    if (_containsAny(source, <String>[
      'admission',
      'apply',
      'deadline',
      'document',
      'test',
      'requirement',
    ])) {
      return 'admission';
    }
    if (_containsAny(source, <String>[
      'faculty',
      'teacher',
      'professor',
      'office',
      'room',
      'email',
      'chairperson',
      'contact',
    ])) {
      return 'faculty';
    }
    if (_containsAny(source, <String>[
      'routine',
      'course',
      'class',
      'prerequisite',
      'lab',
      'section',
      'credit hour',
    ])) {
      return 'routine';
    }
    if (_containsAny(source, <String>[
      'club',
      'campus',
      'facility',
      'library',
      'student life',
      'transport',
    ])) {
      return 'campus';
    }
    if (_containsAny(source, <String>[
      'grading',
      'grade',
      'cgpa',
      'gpa',
      'retake',
      'marks',
    ])) {
      return 'grading';
    }
    return '';
  }

  static bool _containsAny(String source, List<String> values) {
    for (final String value in values) {
      if (source.contains(value)) {
        return true;
      }
    }
    return false;
  }

  static List<String> _clean(List<String> values) {
    final List<String> results = <String>[];
    for (final String value in values) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty || results.contains(trimmed)) {
        continue;
      }
      results.add(trimmed);
    }
    return results;
  }
}
