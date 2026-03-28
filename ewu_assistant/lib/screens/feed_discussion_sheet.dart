import 'package:flutter/material.dart';

import '../models/feed_post.dart';
import '../models/student_profile.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_confirmation_dialog.dart';

class FeedDiscussionSheet extends StatefulWidget {
  const FeedDiscussionSheet({
    super.key,
    required this.feedService,
    required this.post,
    required this.profile,
    required this.onMessage,
  });

  final FeedService feedService;
  final FeedPost post;
  final StudentProfile? profile;
  final ValueChanged<String> onMessage;

  @override
  State<FeedDiscussionSheet> createState() => _FeedDiscussionSheetState();
}

class _FeedDiscussionSheetState extends State<FeedDiscussionSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final StudentProfile? profile = widget.profile;
    final String body = _commentController.text.trim();
    if (profile == null || body.isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.feedService.addComment(
        widget.post.id,
        FeedComment(
          id: '',
          authorName: profile.name,
          authorEmail: profile.email,
          authorStudentId: profile.studentId,
          authorPhotoUrl: profile.photoUrl,
          authorRole: profile.role,
          body: body,
          timestamp: DateTime.now(),
          replyCount: 0,
          reactions: const <String, List<String>>{
            'like': <String>[],
            'heart': <String>[],
            'laugh': <String>[],
          },
        ),
      );
      if (!mounted) {
        return;
      }
      _commentController.clear();
    } catch (error) {
      widget.onMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentEmail =
        AuthService.currentUser?.email?.trim().toLowerCase() ?? '';
    final bool canModerate = AuthService.canModerateContent;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Post discussion',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.post.title.trim().isNotEmpty
                  ? widget.post.title
                  : widget.post.body.trim().isEmpty
                  ? 'Join the discussion below.'
                  : widget.post.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<List<FeedComment>>(
                stream: widget.feedService.getComments(widget.post.id),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<FeedComment>> snapshot,
                    ) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'We could not sync this discussion yet. Please try reopening it.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final List<FeedComment> comments =
                          snapshot.data ?? const <FeedComment>[];
                      if (comments.isEmpty) {
                        return const Center(
                          child: Text(
                            'No comments yet. Start the discussion.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: comments.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int index) {
                          final FeedComment comment = comments[index];
                          return _CommentCard(
                            postId: widget.post.id,
                            comment: comment,
                            currentEmail: currentEmail,
                            canModerate: canModerate,
                            feedService: widget.feedService,
                            profile: widget.profile,
                            onMessage: widget.onMessage,
                          );
                        },
                      );
                    },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: widget.profile == null || _isSubmitting
                      ? null
                      : _submitComment,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.postId,
    required this.comment,
    required this.currentEmail,
    required this.canModerate,
    required this.feedService,
    required this.profile,
    required this.onMessage,
  });

  final String postId;
  final FeedComment comment;
  final String currentEmail;
  final bool canModerate;
  final FeedService feedService;
  final StudentProfile? profile;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final bool isOwner = comment.authorEmail.toLowerCase() == currentEmail;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.botBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryDark,
                backgroundImage: comment.authorPhotoUrl.isNotEmpty
                    ? NetworkImage(comment.authorPhotoUrl)
                    : null,
                child: comment.authorPhotoUrl.isEmpty
                    ? Text(
                        comment.authorName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        Text(
                          comment.authorName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (comment.authorRole != StudentProfile.userRole)
                          _RoleBadge(role: comment.authorRole),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(comment.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner || canModerate)
                IconButton(
                  onPressed: () => _deleteComment(context),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(comment.body),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final String reaction in FeedPost.reactionTypes)
                _ReactionButton(
                  label: _reactionLabel(reaction),
                  count: comment.reactionCount(reaction),
                  selected: comment.reactedBy(currentEmail, reaction),
                  onTap: () async {
                    try {
                      await feedService.toggleCommentReaction(
                        postId: postId,
                        commentId: comment.id,
                        reaction: reaction,
                        email: currentEmail,
                      );
                    } catch (error) {
                      onMessage(
                        error.toString().replaceFirst('Exception: ', ''),
                      );
                    }
                  },
                ),
              TextButton.icon(
                onPressed: profile == null
                    ? null
                    : () => _showReplyComposer(context),
                icon: const Icon(Icons.reply_outlined),
                label: Text(
                  comment.replyCount > 0
                      ? '${comment.replyCount} replies'
                      : 'Reply',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<FeedReply>>(
            stream: feedService.getReplies(postId, comment.id),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<FeedReply>> snapshot,
                ) {
                  final List<FeedReply> replies =
                      snapshot.data ?? const <FeedReply>[];
                  if (replies.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: replies.map((FeedReply reply) {
                      final bool canDeleteReply =
                          canModerate ||
                          reply.authorEmail.toLowerCase() == currentEmail;
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: <Widget>[
                                        Text(
                                          reply.authorName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (reply.authorRole !=
                                            StudentProfile.userRole)
                                          _RoleBadge(role: reply.authorRole),
                                      ],
                                    ),
                                  ),
                                  if (canDeleteReply)
                                    IconButton(
                                      onPressed: () =>
                                          _deleteReply(context, reply),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(reply.body),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: <Widget>[
                                  for (final String reaction
                                      in FeedPost.reactionTypes)
                                    _ReactionButton(
                                      label: _reactionLabel(reaction),
                                      count: reply.reactionCount(reaction),
                                      selected: reply.reactedBy(
                                        currentEmail,
                                        reaction,
                                      ),
                                      onTap: () async {
                                        try {
                                          await feedService.toggleReplyReaction(
                                            postId: postId,
                                            commentId: comment.id,
                                            replyId: reply.id,
                                            reaction: reaction,
                                            email: currentEmail,
                                          );
                                        } catch (error) {
                                          onMessage(
                                            error.toString().replaceFirst(
                                              'Exception: ',
                                              '',
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(BuildContext context) async {
    final bool confirmed = await showAppConfirmationDialog(
      context,
      title: 'Delete comment?',
      message: 'This will remove the comment and its replies.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    try {
      await feedService.deleteComment(postId, comment);
      onMessage('Comment deleted.');
    } catch (error) {
      onMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteReply(BuildContext context, FeedReply reply) async {
    final bool confirmed = await showAppConfirmationDialog(
      context,
      title: 'Delete reply?',
      message: 'This will remove the reply from the discussion.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    try {
      await feedService.deleteReply(
        postId: postId,
        commentId: comment.id,
        reply: reply,
      );
      onMessage('Reply deleted.');
    } catch (error) {
      onMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showReplyComposer(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return _ReplyComposerSheet(
          comment: comment,
          profile: profile,
          feedService: feedService,
          postId: postId,
          onMessage: onMessage,
        );
      },
    );
  }

  String _reactionLabel(String reaction) {
    switch (reaction) {
      case 'heart':
        return '❤️';
      case 'laugh':
        return '😂';
      default:
        return '👍';
    }
  }
}

class _ReplyComposerSheet extends StatefulWidget {
  const _ReplyComposerSheet({
    required this.comment,
    required this.profile,
    required this.feedService,
    required this.postId,
    required this.onMessage,
  });

  final FeedComment comment;
  final StudentProfile? profile;
  final FeedService feedService;
  final String postId;
  final ValueChanged<String> onMessage;

  @override
  State<_ReplyComposerSheet> createState() => _ReplyComposerSheetState();
}

class _ReplyComposerSheetState extends State<_ReplyComposerSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final StudentProfile? safeProfile = widget.profile;
    final String body = _controller.text.trim();
    if (safeProfile == null || body.isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.feedService.addReply(
        widget.postId,
        widget.comment.id,
        FeedReply(
          id: '',
          authorName: safeProfile.name,
          authorEmail: safeProfile.email,
          authorStudentId: safeProfile.studentId,
          authorPhotoUrl: safeProfile.photoUrl,
          authorRole: safeProfile.role,
          body: body,
          timestamp: DateTime.now(),
          reactions: const <String, List<String>>{
            'like': <String>[],
            'heart': <String>[],
            'laugh': <String>[],
          },
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      widget.onMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reply to ${widget.comment.authorName}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Write your reply...'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? 'Sending...' : 'Send reply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          count > 0 ? '$label $count' : label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : AppTheme.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = role == StudentProfile.superAdminRole;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSuperAdmin ? AppTheme.primaryDark : AppTheme.botBubble,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isSuperAdmin ? 'Super Admin' : 'Admin',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isSuperAdmin ? Colors.white : AppTheme.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
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
      : '${local.day}/${local.month}/${local.year}';
}
