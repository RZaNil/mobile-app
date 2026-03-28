import 'package:cloud_firestore/cloud_firestore.dart';

class NoteItem {
  const NoteItem({
    required this.id,
    required this.courseCode,
    required this.courseTag,
    required this.title,
    required this.description,
    required this.uploaderUid,
    required this.uploaderName,
    required this.imageUrls,
    required this.pdfUrl,
    required this.pdfFileName,
    required this.createdAt,
  });

  final String id;
  final String courseCode;
  final String courseTag;
  final String title;
  final String description;
  final String uploaderUid;
  final String uploaderName;
  final List<String> imageUrls;
  final String pdfUrl;
  final String pdfFileName;
  final DateTime createdAt;

  String get imageUrl => imageUrls.isEmpty ? '' : imageUrls.first;
  bool get hasImage => imageUrls.isNotEmpty;
  bool get hasPdf => pdfUrl.trim().isNotEmpty;
  bool get hasAttachments => hasImage || hasPdf;
  int get attachmentCount => imageUrls.length + (hasPdf ? 1 : 0);

  String get attachmentLabel {
    if (!hasAttachments) {
      return 'No attachment';
    }
    if (hasImage && hasPdf) {
      return imageUrls.length > 1
          ? '${imageUrls.length} images + PDF'
          : 'Image + PDF';
    }
    if (hasImage) {
      return imageUrls.length > 1 ? '${imageUrls.length} images' : 'Image';
    }
    return 'PDF';
  }

  String get descriptionPreview {
    final String trimmed = description.trim();
    if (trimmed.length <= 110) {
      return trimmed;
    }
    return '${trimmed.substring(0, 107)}...';
  }

  NoteItem copyWith({
    String? id,
    String? courseCode,
    String? courseTag,
    String? title,
    String? description,
    String? uploaderUid,
    String? uploaderName,
    List<String>? imageUrls,
    String? pdfUrl,
    String? pdfFileName,
    DateTime? createdAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      courseCode: courseCode ?? this.courseCode,
      courseTag: courseTag ?? this.courseTag,
      title: title ?? this.title,
      description: description ?? this.description,
      uploaderUid: uploaderUid ?? this.uploaderUid,
      uploaderName: uploaderName ?? this.uploaderName,
      imageUrls: imageUrls ?? this.imageUrls,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfFileName: pdfFileName ?? this.pdfFileName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NoteItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final String legacyFileUrl = data['fileUrl']?.toString() ?? '';
    final List<String> imageUrls = _parseImageUrls(data, legacyFileUrl);
    final String pdfUrl =
        data['pdfUrl']?.toString() ??
        (_looksLikePdf(legacyFileUrl) ? legacyFileUrl : '');
    final String pdfFileName =
        data['pdfFileName']?.toString() ?? _fileNameFromUrl(pdfUrl);

    return NoteItem(
      id: doc.id,
      courseCode: data['courseCode']?.toString() ?? '',
      courseTag: data['courseTag']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      uploaderUid: data['uploaderUid']?.toString() ?? '',
      uploaderName: data['uploaderName']?.toString() ?? 'EWU Student',
      imageUrls: imageUrls,
      pdfUrl: pdfUrl,
      pdfFileName: pdfFileName,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'courseCode': courseCode,
      'courseTag': courseTag,
      'title': title,
      'description': description,
      'uploaderUid': uploaderUid,
      'uploaderName': uploaderName,
      'imageUrls': imageUrls,
      'imageUrl': imageUrl,
      'pdfUrl': pdfUrl,
      'pdfFileName': pdfFileName,
      'fileUrl': pdfUrl.isNotEmpty ? pdfUrl : imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime _parseDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static List<String> _parseImageUrls(
    Map<String, dynamic> data,
    String legacyFileUrl,
  ) {
    final Object? raw = data['imageUrls'];
    final List<String> urls = <String>[];
    if (raw is List) {
      for (final Object? value in raw) {
        final String url = value?.toString().trim() ?? '';
        if (url.isNotEmpty) {
          urls.add(url);
        }
      }
    }

    final String singleImageUrl = data['imageUrl']?.toString().trim() ?? '';
    if (singleImageUrl.isNotEmpty && !urls.contains(singleImageUrl)) {
      urls.add(singleImageUrl);
    }

    if (!_looksLikePdf(legacyFileUrl) &&
        legacyFileUrl.trim().isNotEmpty &&
        !urls.contains(legacyFileUrl.trim())) {
      urls.add(legacyFileUrl.trim());
    }

    return urls;
  }

  static bool _looksLikePdf(String value) {
    final String normalized = value.trim().toLowerCase();
    return normalized.endsWith('.pdf') || normalized.contains('/raw/upload/');
  }

  static String _fileNameFromUrl(String url) {
    if (url.trim().isEmpty) {
      return '';
    }
    final Uri? uri = Uri.tryParse(url);
    final List<String> segments = uri?.pathSegments ?? <String>[];
    if (segments.isEmpty) {
      return '';
    }
    return Uri.decodeComponent(segments.last);
  }
}
