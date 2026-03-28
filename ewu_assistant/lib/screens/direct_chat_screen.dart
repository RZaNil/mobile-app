import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/direct_chat.dart';
import '../models/student_profile.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/media_permission_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_confirmation_dialog.dart';

const String _emojiLike = '\u{1F44D}';
const String _emojiHeart = '\u{2764}\u{FE0F}';
const String _emojiLaugh = '\u{1F602}';

class DirectChatScreen extends StatefulWidget {
  DirectChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
    SocialService? socialService,
  }) : socialService = socialService ?? SocialService();

  final String chatId;
  final UserDirectoryRecord otherUser;
  final SocialService socialService;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool _isSending = false;
  File? _pendingImageFile;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_refreshComposer);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(widget.socialService.markChatSeen(widget.chatId));
      }
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_refreshComposer);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _refreshComposer() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canSend =>
      !_isSending &&
      (_messageController.text.trim().isNotEmpty || _pendingImageFile != null);

  Future<void> _pickImage() async {
    if (_isSending) {
      return;
    }
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) {
      return;
    }
    try {
      final MediaPermissionResult permission =
          await MediaPermissionService.ensureAccess(source);
      if (!permission.granted) {
        _showMessage(permission.message);
        return;
      }

      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (picked != null && mounted) {
        setState(() {
          _pendingImageFile = File(picked.path);
        });
      }
    } catch (_) {
      _showMessage('We could not open the image picker right now.');
    }
  }

  Future<void> _sendMessage() async {
    if (!_canSend) {
      return;
    }
    setState(() {
      _isSending = true;
    });
    try {
      String imageUrl = '';
      if (_pendingImageFile != null) {
        imageUrl = await _cloudinaryService.uploadImage(_pendingImageFile!);
      }
      await widget.socialService.sendMessage(
        chatId: widget.chatId,
        otherUid: widget.otherUser.uid,
        text: _messageController.text.trim(),
        imageUrl: imageUrl,
      );
      if (!mounted) {
        return;
      }
      _messageController.clear();
      setState(() {
        _pendingImageFile = null;
      });
      _messageFocusNode.requestFocus();
      _scrollToBottom();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _handleAction(
    DirectChatMessage message,
    _MessageAction action,
  ) async {
    switch (action) {
      case _MessageAction.like:
        await _toggleReaction(message, 'like');
      case _MessageAction.heart:
        await _toggleReaction(message, 'heart');
      case _MessageAction.laugh:
        await _toggleReaction(message, 'laugh');
      case _MessageAction.unsend:
        final bool confirmed = await showAppConfirmationDialog(
          context,
          title: 'Remove message?',
          message: 'This will unsend the message for everyone in this chat.',
          confirmLabel: 'Unsend',
          destructive: true,
        );
        if (!confirmed) {
          return;
        }
        try {
          await widget.socialService.deleteOwnMessage(
            chatId: widget.chatId,
            message: message,
          );
          _showMessage('Message removed.');
        } catch (error) {
          _showMessage(error.toString().replaceFirst('Exception: ', ''));
        }
    }
  }

  Future<void> _toggleReaction(
    DirectChatMessage message,
    String reaction,
  ) async {
    try {
      await widget.socialService.toggleMessageReaction(
        chatId: widget.chatId,
        messageId: message.id,
        reaction: reaction,
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentProfile profile = widget.otherUser.profile;
    final String currentUid = AuthService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 4,
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryDark,
              backgroundImage: profile.photoUrl.isNotEmpty
                  ? NetworkImage(profile.photoUrl)
                  : null,
              child: profile.photoUrl.isEmpty
                  ? Text(
                      (profile.firstName.isNotEmpty
                              ? profile.firstName
                              : (profile.name.isNotEmpty ? profile.name : 'E'))
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _subtitleForProfile(profile),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF4F8FD), Color(0xFFF9FBFF), Colors.white],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<DirectChatMessage>>(
                  stream: widget.socialService.watchMessages(widget.chatId),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<DirectChatMessage>> snapshot,
                      ) {
                        final List<DirectChatMessage> messages =
                            snapshot.data ?? const <DirectChatMessage>[];
                        final String errorText =
                            snapshot.error?.toString().toLowerCase() ?? '';
                        final bool blocked =
                            errorText.contains('permission-denied') ||
                            errorText.contains('permission');

                        if (snapshot.hasError) {
                          return _ChatStateView(
                            title: blocked
                                ? 'Messaging needs a Firestore check'
                                : 'We could not sync this chat',
                            description: blocked
                                ? 'Make sure signed-in chat participants can read and write both chats and chat messages.'
                                : 'Please reopen the conversation in a moment.',
                          );
                        }
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            messages.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (_lastMessageCount != messages.length) {
                          _lastMessageCount = messages.length;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) {
                              return;
                            }
                            _scrollToBottom();
                            unawaited(
                              widget.socialService.markChatSeen(widget.chatId),
                            );
                          });
                        }
                        if (messages.isEmpty) {
                          return _ChatStateView(
                            title: 'Start your conversation',
                            description:
                                'Send a message or a photo to begin chatting with ${profile.firstName}.',
                          );
                        }
                        return ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                          itemCount: messages.length,
                          itemBuilder: (BuildContext context, int index) {
                            final DirectChatMessage message = messages[index];
                            return _MessageBubble(
                              message: message,
                              isMine: message.senderUid == currentUid,
                              onAction: (_MessageAction action) =>
                                  _handleAction(message, action),
                            );
                          },
                        );
                      },
                ),
              ),
              if (_pendingImageFile != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _PendingImageCard(
                    file: _pendingImageFile!,
                    onRemove: _isSending
                        ? null
                        : () => setState(() => _pendingImageFile = null),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).padding.bottom +
                      12,
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppTheme.primaryDark.withValues(alpha: 0.08),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppTheme.primaryDark.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      IconButton(
                        onPressed: _isSending ? null : _pickImage,
                        icon: const Icon(Icons.image_outlined),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.botBubble,
                          foregroundColor: AppTheme.primaryDark,
                          minimumSize: const Size(46, 46),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          textInputAction: TextInputAction.send,
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: 'Type your message...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _canSend ? _sendMessage : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onAction,
  });

  final DirectChatMessage message;
  final bool isMine;
  final ValueChanged<_MessageAction> onAction;

  @override
  Widget build(BuildContext context) {
    final Color bubbleColor = isMine
        ? AppTheme.primaryDark
        : const Color(0xFFEAF3FB);
    final Color textColor = isMine ? Colors.white : AppTheme.textPrimary;
    final List<String> reactions = <String>[
      for (final String type in DirectChatMessage.supportedReactions)
        if (message.reactionCount(type) > 0)
          '${_emojiFor(type)} ${message.reactionCount(type)}',
    ];

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onLongPress: message.isDeleted ? null : () => _showActions(context),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isMine ? 24 : 8),
                  bottomRight: Radius.circular(isMine ? 8 : 24),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (message.hasImage && !message.isDeleted) ...<Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        message.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) => Container(
                              height: 180,
                              color: Colors.white.withValues(alpha: 0.28),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                      ),
                    ),
                    if (message.hasText) const SizedBox(height: 10),
                  ],
                  Text(
                    message.isDeleted
                        ? 'Message removed'
                        : (message.text.isEmpty ? 'Photo' : message.text),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: textColor.withValues(
                        alpha: message.isDeleted ? 0.78 : 1,
                      ),
                      fontStyle: message.isDeleted
                          ? FontStyle.italic
                          : FontStyle.normal,
                      height: 1.38,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.68),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (reactions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: reactions
                          .map(
                            (String label) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? Colors.white.withValues(alpha: 0.16)
                                    : Colors.white.withValues(alpha: 0.84),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                label,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: isMine
                                          ? Colors.white
                                          : AppTheme.primaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Text(_emojiLike, style: TextStyle(fontSize: 20)),
              title: const Text('React with thumbs up'),
              onTap: () {
                Navigator.of(context).pop();
                onAction(_MessageAction.like);
              },
            ),
            ListTile(
              leading: const Text(_emojiHeart, style: TextStyle(fontSize: 20)),
              title: const Text('React with heart'),
              onTap: () {
                Navigator.of(context).pop();
                onAction(_MessageAction.heart);
              },
            ),
            ListTile(
              leading: const Text(_emojiLaugh, style: TextStyle(fontSize: 20)),
              title: const Text('React with laugh'),
              onTap: () {
                Navigator.of(context).pop();
                onAction(_MessageAction.laugh);
              },
            ),
            if (isMine && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Unsend message'),
                onTap: () {
                  Navigator.of(context).pop();
                  onAction(_MessageAction.unsend);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingImageCard extends StatelessWidget {
  const _PendingImageCard({required this.file, required this.onRemove});

  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.botBubble,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(file, height: 52, width: 52, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Photo ready to send',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChatStateView extends StatelessWidget {
  const _ChatStateView({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
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

enum _MessageAction { like, heart, laugh, unsend }

String _subtitleForProfile(StudentProfile profile) {
  final List<String> values = <String>[];
  if (profile.studentId.isNotEmpty) {
    values.add(profile.studentId);
  }
  if (profile.department.isNotEmpty) {
    values.add(profile.department);
  }
  if (values.isEmpty) {
    values.add(profile.email);
  }
  return values.join(' | ');
}

String _formatMessageTime(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  final DateTime now = DateTime.now();
  final bool isToday =
      now.year == local.year &&
      now.month == local.month &&
      now.day == local.day;
  final String minute = local.minute.toString().padLeft(2, '0');
  final int rawHour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final String suffix = local.hour >= 12 ? 'PM' : 'AM';
  return isToday
      ? '$rawHour:$minute $suffix'
      : '${local.day}/${local.month} $rawHour:$minute $suffix';
}

String _emojiFor(String reaction) {
  switch (reaction) {
    case 'heart':
      return _emojiHeart;
    case 'laugh':
      return _emojiLaugh;
    default:
      return _emojiLike;
  }
}
