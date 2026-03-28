import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/note_item.dart';
import '../models/student_profile.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/media_permission_service.dart';
import '../services/services_hub_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_confirmation_dialog.dart';
import 'note_detail_screen.dart';

class ServicesNotesTab extends StatefulWidget {
  const ServicesNotesTab({super.key});

  @override
  State<ServicesNotesTab> createState() => _ServicesNotesTabState();
}

class _ServicesNotesTabState extends State<ServicesNotesTab> {
  final ServicesHubService _servicesHubService = ServicesHubService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _openComposer({NoteItem? note}) async {
    final StudentProfile? profile = await AuthService.getProfile();
    final String? uid = AuthService.currentUser?.uid;
    if (!mounted) {
      return;
    }
    if (profile == null || uid == null) {
      _showMessage('Please sign in again to manage notes.');
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
        return _NoteComposerSheet(
          existingNote: note,
          profile: profile,
          uploaderUid: uid,
          servicesHubService: _servicesHubService,
          onMessage: _showMessage,
        );
      },
    );
  }

  Future<void> _openNote(NoteItem note) async {
    await Navigator.of(context).push(
      MaterialPageRoute<NoteDetailScreen>(
        builder: (_) => NoteDetailScreen(note: note),
      ),
    );
  }

  Future<void> _deleteNote(NoteItem note) async {
    final bool confirmed = await showAppConfirmationDialog(
      context,
      title: 'Delete note?',
      message: 'This will remove "${note.title}" from the notes list.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    try {
      await _servicesHubService.deleteNote(note.id);
      _showMessage('Note removed.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<NoteItem> _filterNotes(List<NoteItem> notes) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return notes;
    }
    return notes.where((NoteItem note) {
      return note.title.toLowerCase().contains(query) ||
          note.courseCode.toLowerCase().contains(query) ||
          note.courseTag.toLowerCase().contains(query) ||
          note.description.toLowerCase().contains(query) ||
          note.uploaderName.toLowerCase().contains(query) ||
          note.pdfFileName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_servicesHubService.isAvailable) {
      return const _NotesEmptyState(
        icon: Icons.menu_book_rounded,
        title: 'Notes need Firebase',
        description:
            'Complete Firebase setup to share course notes and attachments.',
      );
    }

    return StreamBuilder<List<NoteItem>>(
      stream: _servicesHubService.getNotes(),
      builder: (BuildContext context, AsyncSnapshot<List<NoteItem>> snapshot) {
        final List<NoteItem> filteredNotes = _filterNotes(
          snapshot.data ?? const <NoteItem>[],
        );
        final String? currentUid = AuthService.currentUser?.uid;
        final bool canModerate = AuthService.canModerateContent;

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _NotesEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Notes unavailable',
            description: 'We could not load notes right now. Please try again.',
          );
        }

        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search notes by course, title, or attachment',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _openComposer(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filteredNotes.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.only(top: 40, bottom: 12),
                      children: <Widget>[
                        _NotesEmptyState(
                          icon: Icons.library_books_outlined,
                          title: _searchController.text.trim().isEmpty
                              ? 'No notes yet'
                              : 'No matching notes',
                          description: _searchController.text.trim().isEmpty
                              ? 'Add the first note to start your shared study library.'
                              : 'Try another course code or keyword.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: filteredNotes.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final NoteItem note = filteredNotes[index];
                        final bool canEdit = note.uploaderUid == currentUid;
                        final bool canDelete = canEdit || canModerate;

                        return Material(
                          color: Colors.transparent,
                          child: Ink(
                            decoration: AppTheme.premiumCard,
                            child: InkWell(
                              onTap: () => _openNote(note),
                              borderRadius: BorderRadius.circular(28),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: <Widget>[
                                                  _InfoChip(
                                                    label: note.courseCode,
                                                    icon: Icons
                                                        .menu_book_outlined,
                                                  ),
                                                  if (note.courseTag.isNotEmpty)
                                                    _InfoChip(
                                                      label: note.courseTag,
                                                      icon: Icons.sell_outlined,
                                                    ),
                                                  if (note.hasAttachments)
                                                    _InfoChip(
                                                      label:
                                                          note.attachmentLabel,
                                                      icon: Icons
                                                          .attach_file_rounded,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                note.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                note.descriptionPreview,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: AppTheme
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (canEdit || canDelete)
                                          PopupMenuButton<String>(
                                            onSelected: (String value) {
                                              if (value == 'edit') {
                                                _openComposer(note: note);
                                              } else {
                                                _deleteNote(note);
                                              }
                                            },
                                            itemBuilder:
                                                (BuildContext context) {
                                                  return <
                                                    PopupMenuEntry<String>
                                                  >[
                                                    if (canEdit)
                                                      const PopupMenuItem<
                                                        String
                                                      >(
                                                        value: 'edit',
                                                        child: Text(
                                                          'Edit note',
                                                        ),
                                                      ),
                                                    if (canDelete)
                                                      const PopupMenuItem<
                                                        String
                                                      >(
                                                        value: 'delete',
                                                        child: Text(
                                                          'Delete note',
                                                        ),
                                                      ),
                                                  ];
                                                },
                                          ),
                                      ],
                                    ),
                                    if (note.hasImage) ...<Widget>[
                                      const SizedBox(height: 12),
                                      _NoteImagePreview(note: note),
                                    ],
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: <Widget>[
                                        _InfoChip(
                                          label: note.uploaderName,
                                          icon: Icons.person_outline_rounded,
                                        ),
                                        _InfoChip(
                                          label: _formatDate(note.createdAt),
                                          icon: Icons.schedule_rounded,
                                        ),
                                        if (note.hasPdf)
                                          _InfoChip(
                                            label: note.pdfFileName.isEmpty
                                                ? 'PDF attached'
                                                : note.pdfFileName,
                                            icon: Icons.picture_as_pdf_outlined,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NoteComposerSheet extends StatefulWidget {
  const _NoteComposerSheet({
    required this.existingNote,
    required this.profile,
    required this.uploaderUid,
    required this.servicesHubService,
    required this.onMessage,
  });

  final NoteItem? existingNote;
  final StudentProfile profile;
  final String uploaderUid;
  final ServicesHubService servicesHubService;
  final ValueChanged<String> onMessage;

  @override
  State<_NoteComposerSheet> createState() => _NoteComposerSheetState();
}

class _NoteComposerSheetState extends State<_NoteComposerSheet> {
  final TextEditingController _courseCodeController = TextEditingController();
  final TextEditingController _courseTagController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _isUploadingPdf = false;
  List<String> _imageUrls = <String>[];
  String _pdfUrl = '';
  String _pdfFileName = '';

  @override
  void initState() {
    super.initState();
    final NoteItem? note = widget.existingNote;
    if (note != null) {
      _courseCodeController.text = note.courseCode;
      _courseTagController.text = note.courseTag;
      _titleController.text = note.title;
      _descriptionController.text = note.description;
      _imageUrls = List<String>.from(note.imageUrls);
      _pdfUrl = note.pdfUrl;
      _pdfFileName = note.pdfFileName;
    }
  }

  @override
  void dispose() {
    _courseCodeController.dispose();
    _courseTagController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _openImageSourcePicker() async {
    if (_isUploadingImage || _isSubmitting) {
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
    await _uploadImages(source);
  }

  Future<void> _uploadImages(ImageSource source) async {
    if (_isUploadingImage || _isSubmitting) {
      return;
    }

    try {
      final MediaPermissionResult permission =
          await MediaPermissionService.ensureAccess(source);
      if (!permission.granted) {
        widget.onMessage(permission.message);
        return;
      }

      setState(() {
        _isUploadingImage = true;
      });

      final List<XFile> pickedFiles;
      if (source == ImageSource.gallery) {
        pickedFiles = await _picker.pickMultiImage(
          imageQuality: 82,
          maxWidth: 1800,
        );
      } else {
        final XFile? captured = await _picker.pickImage(
          source: source,
          imageQuality: 82,
          maxWidth: 1800,
        );
        pickedFiles = captured == null ? <XFile>[] : <XFile>[captured];
      }

      if (pickedFiles.isEmpty) {
        return;
      }

      final List<String> uploadedUrls = <String>[];
      for (final XFile file in pickedFiles) {
        uploadedUrls.add(await _cloudinaryService.uploadImage(File(file.path)));
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _imageUrls = <String>[..._imageUrls, ...uploadedUrls];
      });
      widget.onMessage(
        uploadedUrls.length == 1
            ? 'Image attached.'
            : '${uploadedUrls.length} images attached.',
      );
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

  Future<void> _uploadPdf() async {
    if (_isUploadingPdf || _isSubmitting) {
      return;
    }

    try {
      setState(() {
        _isUploadingPdf = true;
      });

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final PlatformFile platformFile = result.files.single;
      final String? path = platformFile.path;
      if (path == null || path.isEmpty) {
        widget.onMessage('We could not read that PDF file.');
        return;
      }

      final String fileName = platformFile.name.trim().isEmpty
          ? 'note_attachment.pdf'
          : platformFile.name.trim();
      final String pdfUrl = await _cloudinaryService.uploadPdf(
        File(path),
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pdfUrl = pdfUrl;
        _pdfFileName = fileName;
      });
      widget.onMessage('PDF attached.');
    } catch (error) {
      widget.onMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPdf = false;
        });
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      _imageUrls = List<String>.from(_imageUrls)..removeAt(index);
    });
  }

  void _removePdf() {
    setState(() {
      _pdfUrl = '';
      _pdfFileName = '';
    });
  }

  Future<void> _save() async {
    final String courseCode = _courseCodeController.text.trim().toUpperCase();
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    if (courseCode.isEmpty || title.isEmpty || description.isEmpty) {
      widget.onMessage('Please add course code, title, and description.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      final NoteItem note = NoteItem(
        id: widget.existingNote?.id ?? '',
        courseCode: courseCode,
        courseTag: _courseTagController.text.trim(),
        title: title,
        description: description,
        uploaderUid: widget.existingNote?.uploaderUid ?? widget.uploaderUid,
        uploaderName: widget.existingNote?.uploaderName ?? widget.profile.name,
        imageUrls: _imageUrls,
        pdfUrl: _pdfUrl,
        pdfFileName: _pdfFileName,
        createdAt: widget.existingNote?.createdAt ?? DateTime.now(),
      );
      await widget.servicesHubService.saveNote(note);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      widget.onMessage(
        widget.existingNote == null ? 'Note added.' : 'Note updated.',
      );
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.existingNote == null ? 'Add note' : 'Edit note',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _courseCodeController,
              decoration: const InputDecoration(
                labelText: 'Course code',
                hintText: 'CSE101',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _courseTagController,
              decoration: const InputDecoration(
                labelText: 'Course tag',
                hintText: 'Theory / Lab / Midterm Pack',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            Text(
              'Attachments',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingImage
                        ? null
                        : _openImageSourcePicker,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _isUploadingImage ? 'Uploading...' : 'Add image',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _isUploadingPdf ? null : _uploadPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(_isUploadingPdf ? 'Uploading...' : 'Add PDF'),
                  ),
                ),
              ],
            ),
            if (_imageUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final String imageUrl = _imageUrls[index];
                    return Stack(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            imageUrl,
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) => Container(
                                  width: 92,
                                  height: 92,
                                  color: AppTheme.botBubble,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: InkWell(
                            onTap: () => _removeImageAt(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            if (_pdfUrl.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.botBubble,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppTheme.primaryDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pdfFileName.isEmpty ? 'PDF attached' : _pdfFileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _removePdf,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting || _isUploadingImage || _isUploadingPdf
                    ? null
                    : _save,
                child: Text(_isSubmitting ? 'Saving...' : 'Save note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteImagePreview extends StatelessWidget {
  const _NoteImagePreview({required this.note});

  final NoteItem note;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 2.2,
            child: Image.network(
              note.imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) => Container(
                    color: AppTheme.botBubble,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
            ),
          ),
          if (note.imageUrls.length > 1)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${note.imageUrls.length - 1} more',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.botBubble,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppTheme.primaryDark),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesEmptyState extends StatelessWidget {
  const _NotesEmptyState({
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.premiumCard,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: AppTheme.botBubble,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: AppTheme.primaryDark, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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

String _formatDate(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
