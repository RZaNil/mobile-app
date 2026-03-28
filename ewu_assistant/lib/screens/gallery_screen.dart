import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gallery_post.dart';
import '../models/student_profile.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/feed_service.dart';
import '../services/media_permission_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_confirmation_dialog.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final FeedService _feedService = FeedService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _refreshGallery() async {
    if (!mounted) {
      return;
    }
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _showUploadSheet() async {
    final StudentProfile? profile = await AuthService.getProfile();
    if (!mounted) {
      return;
    }
    if (profile == null) {
      _showMessage('Please sign in again before uploading.');
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
        return _GalleryUploadSheet(
          onPick:
              ({required ImageSource source, required String caption}) async {
                await _pickAndUpload(
                  source: source,
                  caption: caption,
                  profile: profile,
                );
              },
        );
      },
    );
  }

  Future<void> _pickAndUpload({
    required ImageSource source,
    required String caption,
    required StudentProfile profile,
  }) async {
    try {
      final MediaPermissionResult permission =
          await MediaPermissionService.ensureAccess(source);
      if (!permission.granted) {
        _showMessage(permission.message);
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

      final String imageUrl = await _cloudinaryService.uploadImage(
        File(file.path),
      );
      await _feedService.createGalleryPost(
        GalleryPost(
          id: '',
          authorName: profile.name,
          authorEmail: profile.email,
          authorStudentId: profile.studentId,
          authorPhotoUrl: profile.photoUrl,
          authorRole: profile.role,
          imageUrl: imageUrl,
          caption: caption,
          likedBy: const <String>[],
          timestamp: DateTime.now(),
        ),
      );
      _showMessage('Image uploaded to the campus gallery.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool> _confirmDelete(GalleryPost post) {
    return showAppConfirmationDialog(
      context,
      title: 'Delete Photo?',
      message:
          'This will remove ${post.caption.isEmpty ? 'this gallery photo' : '"${post.caption}"'} from the campus gallery.',
      confirmLabel: 'Delete Photo',
      destructive: true,
    );
  }

  void _showPreview(GalleryPost post) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: InteractiveViewer(
                  child: Image.network(
                    post.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) => Container(
                          color: Colors.black12,
                          height: 300,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                          ),
                        ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      children: <Widget>[
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: <Widget>[
                Text(
                  'Campus Gallery',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _showUploadSheet,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Upload Photo'),
                ),
              ],
            ),
          ),
        Expanded(child: _buildGalleryGrid()),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Campus Gallery')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadSheet,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Upload Photo'),
      ),
      body: content,
    );
  }

  Widget _buildGalleryGrid() {
    if (!_feedService.isAvailable) {
      return const _GalleryPlaceholder(
        title: 'Gallery Needs Firebase',
        description:
            'Finish Firebase and Cloudinary setup to enable photo sharing.',
      );
    }

    return StreamBuilder<List<GalleryPost>>(
      stream: _feedService.getGalleryPosts(),
      builder: (BuildContext context, AsyncSnapshot<List<GalleryPost>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const _GalleryPlaceholder(
            title: 'Unable To Load Gallery',
            description: 'Please check Firebase and Cloudinary configuration.',
          );
        }

        final List<GalleryPost> posts = snapshot.data ?? const <GalleryPost>[];
        if (posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshGallery,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 64, left: 24, right: 24),
              children: const <Widget>[
                _GalleryPlaceholder(
                  title: 'No Photos Yet',
                  description:
                      'Upload the first campus photo to start the shared gallery.',
                ),
              ],
            ),
          );
        }

        final String currentEmail =
            AuthService.currentUser?.email?.toLowerCase() ?? '';
        final bool canModerate = AuthService.canModerateContent;

        return RefreshIndicator(
          onRefresh: _refreshGallery,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.7,
            ),
            itemCount: posts.length,
            itemBuilder: (BuildContext context, int index) {
              final GalleryPost post = posts[index];
              final bool isOwner =
                  currentEmail == post.authorEmail.toLowerCase();
              final bool canDelete = isOwner || canModerate;

              return Container(
                decoration: AppTheme.glassCard,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showPreview(post),
                          child: Ink.image(
                            image: NetworkImage(post.imageUrl),
                            fit: BoxFit.cover,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.black38,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () async {
                                      try {
                                        await _feedService.toggleGalleryLike(
                                          post.id,
                                          currentEmail,
                                        );
                                      } catch (error) {
                                        _showMessage(
                                          error.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.favorite_border_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            post.caption.isEmpty
                                ? 'Campus moment'
                                : post.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.primaryDark,
                                backgroundImage: post.authorPhotoUrl.isNotEmpty
                                    ? NetworkImage(post.authorPhotoUrl)
                                    : null,
                                child: post.authorPhotoUrl.isEmpty
                                    ? Text(
                                        post.authorName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      post.authorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (post.authorRole !=
                                        StudentProfile.userRole) ...<Widget>[
                                      const SizedBox(height: 4),
                                      _GalleryRoleBadge(role: post.authorRole),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${post.likes} likes | ${_formatGalleryDate(post.timestamp)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          if (canDelete)
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                onPressed: () async {
                                  final bool confirmed = await _confirmDelete(
                                    post,
                                  );
                                  if (!confirmed) {
                                    return;
                                  }
                                  try {
                                    await _feedService.deleteGalleryPost(
                                      post.id,
                                    );
                                    _showMessage('Photo removed from gallery.');
                                  } catch (error) {
                                    _showMessage(
                                      error.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GalleryUploadSheet extends StatefulWidget {
  const _GalleryUploadSheet({required this.onPick});

  final Future<void> Function({
    required ImageSource source,
    required String caption,
  })
  onPick;

  @override
  State<_GalleryUploadSheet> createState() => _GalleryUploadSheetState();
}

class _GalleryUploadSheetState extends State<_GalleryUploadSheet> {
  final TextEditingController _captionController = TextEditingController();
  bool _isClosing = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _handlePick(ImageSource source) async {
    if (_isClosing) {
      return;
    }

    setState(() {
      _isClosing = true;
    });

    final String caption = _captionController.text.trim();
    Navigator.of(context).pop();
    await widget.onPick(source: source, caption: caption);
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
            'Upload To Gallery',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Share a campus memory from your camera or gallery.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _captionController,
            decoration: const InputDecoration(
              labelText: 'Caption',
              hintText: 'Share a short note about this moment',
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isClosing
                      ? null
                      : () => _handlePick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isClosing
                      ? null
                      : () => _handlePick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GalleryPlaceholder extends StatelessWidget {
  const _GalleryPlaceholder({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.glassCard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.photo_library_outlined,
                size: 42,
                color: AppTheme.primaryDark,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryRoleBadge extends StatelessWidget {
  const _GalleryRoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = role == StudentProfile.superAdminRole;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

String _formatGalleryDate(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
