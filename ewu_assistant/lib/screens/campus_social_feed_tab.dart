import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/feed_post.dart';
import '../models/student_profile.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/feed_service.dart';
import '../services/media_permission_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_confirmation_dialog.dart';
import 'feed_discussion_sheet.dart';

class CampusSocialFeedTab extends StatefulWidget {
  const CampusSocialFeedTab({super.key});

  @override
  State<CampusSocialFeedTab> createState() => _CampusSocialFeedTabState();
}

class _CampusSocialFeedTabState extends State<CampusSocialFeedTab> {
  final FeedService _feedService = FeedService();

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<StudentProfile?> _loadProfileForPosting() async {
    final StudentProfile? profile = await AuthService.getProfile();
    if (!mounted) {
      return null;
    }
    if (profile == null) {
      _showMessage('Please sign in again to continue.');
      return null;
    }
    return profile;
  }

  Future<void> _showPostComposer({FeedPost? existingPost}) async {
    final StudentProfile? profile = await _loadProfileForPosting();
    if (!mounted) {
      return;
    }
    if (profile == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return _PostComposerSheet(
          feedService: _feedService,
          profile: profile,
          initialPost: existingPost,
          onMessage: _showMessage,
        );
      },
    );
  }

  Future<void> _showCommentsSheet(FeedPost post) async {
    final StudentProfile? profile = await AuthService.getProfile();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return FeedDiscussionSheet(
          feedService: _feedService,
          post: post,
          profile: profile,
          onMessage: _showMessage,
        );
      },
    );
  }

  Future<void> _togglePostReaction(FeedPost post, String reaction) async {
    final String currentEmail =
        AuthService.currentUser?.email?.trim().toLowerCase() ?? '';
    try {
      await _feedService.toggleReaction(post.id, reaction, currentEmail);
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deletePost(FeedPost post) async {
    final bool confirmed = await showAppConfirmationDialog(
      context,
      title: 'Delete post?',
      message: 'This will remove the post and its discussion thread.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    try {
      await _feedService.deletePost(post.id);
      _showMessage('Post deleted.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _refreshFeed() async {
    if (!mounted) {
      return;
    }
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 280));
  }

  @override
  Widget build(BuildContext context) {
    if (!_feedService.isAvailable) {
      return const _FeedEmptyState(
        icon: Icons.forum_outlined,
        title: 'Campus feed needs Firebase',
        description:
            'Complete your Firebase setup to enable real-time campus posts and discussions.',
      );
    }

    return StreamBuilder<List<FeedPost>>(
      stream: _feedService.getPosts(),
      builder: (BuildContext context, AsyncSnapshot<List<FeedPost>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _FeedEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load feed',
            description:
                'Please check your connection and try opening the feed again.',
          );
        }

        final List<FeedPost> posts = snapshot.data ?? const <FeedPost>[];
        final String currentEmail =
            AuthService.currentUser?.email?.trim().toLowerCase() ?? '';
        final bool canModerate = AuthService.canModerateContent;

        return RefreshIndicator(
          onRefresh: _refreshFeed,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 106),
            itemCount: posts.isEmpty ? 2 : posts.length + 1,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showPostComposer(),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Share post'),
                  ),
                );
              }

              if (posts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 52),
                  child: _FeedEmptyState(
                    icon: Icons.edit_note_outlined,
                    title: 'No posts yet',
                    description:
                        'Share the first update, question, or photo to start the campus conversation.',
                  ),
                );
              }

              final FeedPost post = posts[index - 1];
              final bool isOwner =
                  currentEmail == post.authorEmail.trim().toLowerCase();

              return _FeedPostCard(
                post: post,
                currentEmail: currentEmail,
                canEdit: isOwner,
                canDelete: isOwner || canModerate,
                onReact: (String reaction) =>
                    _togglePostReaction(post, reaction),
                onOpenComments: () => _showCommentsSheet(post),
                onEdit: isOwner
                    ? () => _showPostComposer(existingPost: post)
                    : null,
                onDelete: (isOwner || canModerate)
                    ? () => _deletePost(post)
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.post,
    required this.currentEmail,
    required this.canEdit,
    required this.canDelete,
    required this.onReact,
    required this.onOpenComments,
    required this.onEdit,
    required this.onDelete,
  });

  final FeedPost post;
  final String currentEmail;
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<String> onReact;
  final VoidCallback onOpenComments;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryDark,
                backgroundImage: post.authorPhotoUrl.isNotEmpty
                    ? NetworkImage(post.authorPhotoUrl)
                    : null,
                child: post.authorPhotoUrl.isEmpty
                    ? Text(
                        post.authorName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            post.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (post.authorRole != StudentProfile.userRole)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _RoleBadge(role: post.authorRole),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${post.displayHandle} | ${_formatDateTime(post.timestamp)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (post.category.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        post.category,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit || canDelete)
                PopupMenuButton<_PostAction>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: Colors.white,
                  onSelected: (_PostAction action) {
                    switch (action) {
                      case _PostAction.edit:
                        onEdit?.call();
                      case _PostAction.delete:
                        onDelete?.call();
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    final List<PopupMenuEntry<_PostAction>> items =
                        <PopupMenuEntry<_PostAction>>[];
                    if (canEdit) {
                      items.add(
                        const PopupMenuItem<_PostAction>(
                          value: _PostAction.edit,
                          child: Text('Edit post'),
                        ),
                      );
                    }
                    if (canDelete) {
                      items.add(
                        const PopupMenuItem<_PostAction>(
                          value: _PostAction.delete,
                          child: Text('Delete post'),
                        ),
                      );
                    }
                    return items;
                  },
                ),
            ],
          ),
          if (post.title.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              post.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (post.body.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              post.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                height: 1.45,
              ),
            ),
          ],
          if (post.hasImage) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                post.imageUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => Container(
                      height: 190,
                      alignment: Alignment.center,
                      color: AppTheme.botBubble,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              for (final String reaction in FeedPost.reactionTypes)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ReactionButton(
                    emoji: _emojiForReaction(reaction),
                    count: post.reactionCount(reaction),
                    selected: post.reactedBy(currentEmail, reaction),
                    onTap: () => onReact(reaction),
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: onOpenComments,
                icon: const Icon(Icons.mode_comment_outlined),
                label: Text(
                  post.commentCount > 0
                      ? '${post.commentCount} comments'
                      : 'Comment',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostComposerSheet extends StatefulWidget {
  const _PostComposerSheet({
    required this.feedService,
    required this.profile,
    required this.onMessage,
    this.initialPost,
  });

  final FeedService feedService;
  final StudentProfile profile;
  final ValueChanged<String> onMessage;
  final FeedPost? initialPost;

  @override
  State<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<_PostComposerSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  late String _selectedCategory;
  late String _imageUrl;
  bool _isUploadingImage = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialPost != null;

  @override
  void initState() {
    super.initState();
    final FeedPost? initialPost = widget.initialPost;
    _selectedCategory = initialPost?.category ?? FeedPost.categories.first;
    _imageUrl = initialPost?.imageUrl ?? '';
    _titleController.text = initialPost?.title ?? '';
    _bodyController.text = initialPost?.body ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isUploadingImage) {
      return;
    }

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final MediaPermissionResult permission =
          await MediaPermissionService.ensureAccess(source);
      if (!permission.granted) {
        widget.onMessage(permission.message);
        return;
      }

      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (file == null) {
        return;
      }
      final String uploadedUrl = await _cloudinaryService.uploadImage(
        File(file.path),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _imageUrl = uploadedUrl;
      });
    } catch (error) {
      widget.onMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty && _imageUrl.isEmpty) {
      widget.onMessage('Add some text or an image before publishing.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final FeedPost? initialPost = widget.initialPost;
      if (initialPost == null) {
        await widget.feedService.createPost(
          FeedPost(
            id: '',
            authorName: widget.profile.name,
            authorEmail: widget.profile.email,
            authorStudentId: widget.profile.studentId,
            authorPhotoUrl: widget.profile.photoUrl,
            authorRole: widget.profile.role,
            category: _selectedCategory,
            title: title,
            body: body,
            imageUrl: _imageUrl,
            timestamp: DateTime.now(),
            likes: 0,
            likedBy: const <String>[],
            replyCount: 0,
            reactions: const <String, List<String>>{
              'like': <String>[],
              'heart': <String>[],
              'laugh': <String>[],
            },
          ),
        );
      } else {
        await widget.feedService.updatePost(
          initialPost.copyWith(
            category: _selectedCategory,
            title: title,
            body: body,
            imageUrl: _imageUrl,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      widget.onMessage(_isEditing ? 'Post updated.' : 'Post published.');
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
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _isEditing ? 'Edit post' : 'Share post',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              items: FeedPost.categories
                  .map(
                    (String category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedCategory = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Headline',
                hintText: 'Optional short title',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Post',
                hintText: 'Write something for the campus feed.',
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.botBubble,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Optional image',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_imageUrl.isNotEmpty) ...<Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _isUploadingImage
                          ? null
                          : () {
                              setState(() {
                                _imageUrl = '';
                              });
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove image'),
                    ),
                  ] else
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingImage
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isUploadingImage
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              _isUploadingImage ? 'Uploading...' : 'Gallery',
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting || _isUploadingImage ? null : _submit,
                child: Text(
                  _isSubmitting
                      ? (_isEditing ? 'Saving...' : 'Publishing...')
                      : (_isEditing ? 'Save changes' : 'Publish post'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryDark : AppTheme.botBubble,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          count > 0 ? '$emoji $count' : emoji,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSuperAdmin ? AppTheme.primaryDark : AppTheme.botBubble,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isSuperAdmin ? 'Super' : 'Admin',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isSuperAdmin ? Colors.white : AppTheme.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
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
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: AppTheme.botBubble,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppTheme.primaryDark),
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

enum _PostAction { edit, delete }

String _emojiForReaction(String reaction) {
  switch (reaction) {
    case 'heart':
      return '❤️';
    case 'laugh':
      return '😂';
    default:
      return '👍';
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
