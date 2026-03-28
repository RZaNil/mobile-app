import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';
import '../services/media_permission_service.dart';
import '../services/smart_tools_service.dart';
import '../theme/app_theme.dart';
import '../widgets/smart_tool_widgets.dart';

class SmartToolsFacultyFinderTab extends StatefulWidget {
  const SmartToolsFacultyFinderTab({super.key});

  @override
  State<SmartToolsFacultyFinderTab> createState() =>
      _SmartToolsFacultyFinderTabState();
}

class _SmartToolsFacultyFinderTabState
    extends State<SmartToolsFacultyFinderTab> {
  final SmartToolsService _smartToolsService = SmartToolsService();
  final TextEditingController _searchController = TextEditingController();
  final List<_FacultyContactItem> _contacts = <_FacultyContactItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> raw = await _smartToolsService
          .loadFacultyContacts();
      if (!mounted) {
        return;
      }
      setState(() {
        _contacts
          ..clear()
          ..addAll(raw.map(_FacultyContactItem.fromJson));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _persist() async {
    await _smartToolsService.saveFacultyContacts(
      _contacts.map((_FacultyContactItem item) => item.toJson()).toList(),
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openEditor({_FacultyContactItem? item}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return _FacultyEditorSheet(
          existingItem: item,
          onSave: (_FacultyContactItem savedItem) async {
            final List<_FacultyContactItem> previousContacts =
                List<_FacultyContactItem>.from(_contacts);
            final int existingIndex = _contacts.indexWhere(
              (_FacultyContactItem value) => value.id == savedItem.id,
            );
            setState(() {
              if (existingIndex == -1) {
                _contacts.add(savedItem);
              } else {
                _contacts[existingIndex] = savedItem;
              }
            });
            try {
              await _persist();
              if (!mounted) {
                return;
              }
              _showMessage(
                item == null ? 'Contact added.' : 'Contact updated.',
              );
            } catch (error) {
              if (!mounted) {
                return;
              }
              setState(() {
                _contacts
                  ..clear()
                  ..addAll(previousContacts);
              });
              _showMessage(error.toString().replaceFirst('Exception: ', ''));
              rethrow;
            }
          },
        );
      },
    );
  }

  Future<void> _delete(_FacultyContactItem item) async {
    final List<_FacultyContactItem> previousContacts =
        List<_FacultyContactItem>.from(_contacts);
    setState(() {
      _contacts.removeWhere((_FacultyContactItem value) => value.id == item.id);
    });
    try {
      await _persist();
      _showMessage('Contact removed.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _contacts
          ..clear()
          ..addAll(previousContacts);
      });
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showPdfLink(String url) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('PDF attachment'),
          content: SelectableText(url),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                _showMessage('PDF link copied.');
              },
              child: const Text('Copy link'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImage(String imageUrl) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => const SizedBox(
                      height: 220,
                      child: Center(child: Text('Image unavailable')),
                    ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final String query = _searchController.text.trim().toLowerCase();
    final List<_FacultyContactItem> filtered = _contacts.where((
      _FacultyContactItem item,
    ) {
      if (query.isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(query) ||
          item.email.toLowerCase().contains(query) ||
          item.phoneNumber.toLowerCase().contains(query) ||
          item.roomNumber.toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: <Widget>[
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search faculty by name, email, phone, or room',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _openEditor,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add Contact'),
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const SmartToolEmptyState(
            icon: Icons.contact_mail_outlined,
            title: 'No faculty contacts yet',
            description:
                'Add a faculty contact with room, phone, image, or PDF notes.',
          )
        else
          ...filtered.map((_FacultyContactItem item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.premiumCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.botBubble,
                          backgroundImage: item.imageUrl.isNotEmpty
                              ? NetworkImage(item.imageUrl)
                              : null,
                          child: item.imageUrl.isEmpty
                              ? Text(
                                  item.name.isEmpty
                                      ? 'F'
                                      : item.name.substring(0, 1).toUpperCase(),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppTheme.primaryDark,
                                        fontWeight: FontWeight.w800,
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
                                item.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                      if (item.roomNumber.isNotEmpty)
                                        item.roomNumber,
                                      if (item.phoneNumber.isNotEmpty)
                                        item.phoneNumber,
                                    ].join(' | ').isEmpty
                                    ? 'Faculty contact'
                                    : [
                                        if (item.roomNumber.isNotEmpty)
                                          item.roomNumber,
                                        if (item.phoneNumber.isNotEmpty)
                                          item.phoneNumber,
                                      ].join(' | '),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (String value) {
                            if (value == 'edit') {
                              _openEditor(item: item);
                            } else {
                              _delete(item);
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              const <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                        ),
                      ],
                    ),
                    if (item.email.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        item.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if (item.imageUrl.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.image_outlined, size: 16),
                            label: const Text('View image'),
                            onPressed: () => _showImage(item.imageUrl),
                          ),
                        if (item.pdfUrl.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 16,
                            ),
                            label: const Text('PDF link'),
                            onPressed: () => _showPdfLink(item.pdfUrl),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _FacultyEditorSheet extends StatefulWidget {
  const _FacultyEditorSheet({required this.existingItem, required this.onSave});

  final _FacultyContactItem? existingItem;
  final Future<void> Function(_FacultyContactItem) onSave;

  @override
  State<_FacultyEditorSheet> createState() => _FacultyEditorSheetState();
}

class _FacultyEditorSheetState extends State<_FacultyEditorSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _pdfController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool _saving = false;
  bool _uploadingImage = false;
  String _imageUrl = '';

  @override
  void initState() {
    super.initState();
    final _FacultyContactItem? item = widget.existingItem;
    if (item != null) {
      _nameController.text = item.name;
      _emailController.text = item.email;
      _phoneController.text = item.phoneNumber;
      _roomController.text = item.roomNumber;
      _pdfController.text = item.pdfUrl;
      _imageUrl = item.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roomController.dispose();
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
    if (_uploadingImage || _saving) {
      return;
    }
    try {
      final MediaPermissionResult permission =
          await MediaPermissionService.ensureAccess(ImageSource.gallery);
      if (!permission.granted) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(permission.message)));
        return;
      }

      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (picked == null) {
        return;
      }
      setState(() {
        _uploadingImage = true;
      });
      final String imageUrl = await _cloudinaryService.uploadImage(
        File(picked.path),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _imageUrl = imageUrl;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add the faculty name.')),
      );
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.onSave(
        _FacultyContactItem(
          id:
              widget.existingItem?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          roomNumber: _roomController.text.trim(),
          imageUrl: _imageUrl,
          pdfUrl: _pdfController.text.trim(),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
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
              widget.existingItem == null ? 'Add contact' : 'Edit contact',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(labelText: 'Room number'),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadingImage ? null : _uploadImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_uploadingImage ? 'Uploading...' : 'Add image'),
                  ),
                ),
                if (_imageUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _imageUrl = ''),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pdfController,
              decoration: const InputDecoration(
                labelText: 'PDF link',
                hintText: 'Paste office-hour PDF or schedule link',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacultyContactItem {
  const _FacultyContactItem({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.roomNumber,
    required this.imageUrl,
    required this.pdfUrl,
  });

  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String roomNumber;
  final String imageUrl;
  final String pdfUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'roomNumber': roomNumber,
      'imageUrl': imageUrl,
      'pdfUrl': pdfUrl,
    };
  }

  factory _FacultyContactItem.fromJson(Map<String, dynamic> json) {
    return _FacultyContactItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      pdfUrl: json['pdfUrl']?.toString() ?? '',
    );
  }
}
