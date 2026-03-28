import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/note_item.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';

class NoteDetailScreen extends StatelessWidget {
  NoteDetailScreen({super.key, required this.note});

  final NoteItem note;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  Future<void> _openPdf(BuildContext context, {required bool download}) async {
    final String baseUrl = note.pdfUrl.trim();
    if (baseUrl.isEmpty) {
      return;
    }

    final String targetUrl = download
        ? _cloudinaryService.buildDownloadUrl(baseUrl)
        : baseUrl;
    final Uri? uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This PDF link is not valid.')),
      );
      return;
    }

    final bool launched = await launchUrl(
      uri,
      mode: download
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            download
                ? 'We could not open the PDF download link.'
                : 'We could not open the PDF right now.',
          ),
        ),
      );
    }
  }

  Future<void> _showImageViewer(BuildContext context, String imageUrl) async {
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
                      height: 260,
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
    return Scaffold(
      backgroundColor: AppTheme.pageTint,
      appBar: AppBar(title: const Text('Note details')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppTheme.premiumCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _NoteMetaChip(
                        icon: Icons.menu_book_outlined,
                        label: note.courseCode,
                      ),
                      if (note.courseTag.isNotEmpty)
                        _NoteMetaChip(
                          icon: Icons.sell_outlined,
                          label: note.courseTag,
                        ),
                      _NoteMetaChip(
                        icon: Icons.attach_file_rounded,
                        label: note.attachmentLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    note.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Shared by ${note.uploaderName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (note.hasImage) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                note.imageUrls.length > 1 ? 'Images' : 'Image',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: note.imageUrls.length > 1 ? 2 : 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: note.imageUrls.length > 1 ? 1.12 : 1.55,
                ),
                itemCount: note.imageUrls.length,
                itemBuilder: (BuildContext context, int index) {
                  final String imageUrl = note.imageUrls[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => _showImageViewer(context, imageUrl),
                      child: Ink(
                        decoration: AppTheme.premiumCard,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) => const Center(
                                  child: Text('Image unavailable'),
                                ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            if (note.hasPdf) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'PDF attachment',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.premiumCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.botBubble,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                note.pdfFileName.isEmpty
                                    ? 'Attached PDF'
                                    : note.pdfFileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Open the PDF or use the download action.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _openPdf(context, download: false),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('View PDF'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openPdf(context, download: true),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteMetaChip extends StatelessWidget {
  const _NoteMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
