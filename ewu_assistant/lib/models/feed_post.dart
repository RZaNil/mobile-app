import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    required this.authorStudentId,
    required this.authorPhotoUrl,
    required this.authorRole,
    required this.category,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.timestamp,
    required this.likes,
    required this.likedBy,
    required this.replyCount,
    required this.reactions,
  });

  static const List<String> reactionTypes = <String>['like', 'heart', 'laugh'];

  final String id;
  final String authorName;
  final String authorEmail;
  final String authorStudentId;
  final String authorPhotoUrl;
  final String authorRole;
  final String category;
  final String title;
  final String body;
  final String imageUrl;
  final DateTime timestamp;
  final int likes;
  final List<String> likedBy;
  final int replyCount;
  final Map<String, List<String>> reactions;

  static const List<String> categories = <String>[
    'General',
    'Academic',
    'Events',
    'Notices',
    'Lost & Found',
  ];

  static const Map<String, IconData> categoryIcons = <String, IconData>{
    'General': Icons.forum_outlined,
    'Academic': Icons.school_outlined,
    'Events': Icons.event_outlined,
    'Notices': Icons.campaign_outlined,
    'Lost & Found': Icons.search_outlined,
  };

  String get displayHandle {
    final String base = authorStudentId.isNotEmpty
        ? authorStudentId
        : authorEmail.split('@').first;
    return '@${base.toLowerCase()}';
  }

  bool get hasImage => imageUrl.trim().isNotEmpty;

  bool get hasText => title.trim().isNotEmpty || body.trim().isNotEmpty;

  int get commentCount => replyCount;

  bool reactedBy(String email, String reactionType) {
    return reactions[reactionType]?.contains(email.trim().toLowerCase()) ??
        false;
  }

  int reactionCount(String reactionType) {
    return reactions[reactionType]?.length ?? 0;
  }

  FeedPost copyWith({
    String? id,
    String? authorName,
    String? authorEmail,
    String? authorStudentId,
    String? authorPhotoUrl,
    String? authorRole,
    String? category,
    String? title,
    String? body,
    String? imageUrl,
    DateTime? timestamp,
    int? likes,
    List<String>? likedBy,
    int? replyCount,
    Map<String, List<String>>? reactions,
  }) {
    return FeedPost(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      authorStudentId: authorStudentId ?? this.authorStudentId,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      authorRole: authorRole ?? this.authorRole,
      category: category ?? this.category,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      replyCount: replyCount ?? this.replyCount,
      reactions: reactions ?? this.reactions,
    );
  }

  factory FeedPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final List<String> likedBy = _stringList(data['likedBy']);
    final Map<String, List<String>> reactions = _parseReactionMap(
      data['reactions'],
      fallbackLikes: likedBy,
    );
    return FeedPost(
      id: doc.id,
      authorName: data['authorName']?.toString() ?? 'EWU Student',
      authorEmail: data['authorEmail']?.toString() ?? '',
      authorStudentId: data['authorStudentId']?.toString() ?? '',
      authorPhotoUrl: data['authorPhotoUrl']?.toString() ?? '',
      authorRole: data['authorRole']?.toString() ?? 'user',
      category: data['category']?.toString() ?? 'General',
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
      likes: (data['likes'] as num?)?.toInt() ?? reactions['like']!.length,
      likedBy: likedBy.isNotEmpty ? likedBy : reactions['like']!,
      replyCount: (data['replyCount'] as num?)?.toInt() ?? 0,
      reactions: reactions,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'authorStudentId': authorStudentId,
      'authorPhotoUrl': authorPhotoUrl,
      'authorRole': authorRole,
      'category': category,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'likedBy': likedBy,
      'replyCount': replyCount,
      'reactions': reactions,
    };
  }
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    required this.authorStudentId,
    required this.authorPhotoUrl,
    required this.authorRole,
    required this.body,
    required this.timestamp,
    required this.replyCount,
    required this.reactions,
  });

  final String id;
  final String authorName;
  final String authorEmail;
  final String authorStudentId;
  final String authorPhotoUrl;
  final String authorRole;
  final String body;
  final DateTime timestamp;
  final int replyCount;
  final Map<String, List<String>> reactions;

  int reactionCount(String reactionType) {
    return reactions[reactionType]?.length ?? 0;
  }

  bool reactedBy(String email, String reactionType) {
    return reactions[reactionType]?.contains(email.trim().toLowerCase()) ??
        false;
  }

  FeedComment copyWith({
    String? id,
    String? authorName,
    String? authorEmail,
    String? authorStudentId,
    String? authorPhotoUrl,
    String? authorRole,
    String? body,
    DateTime? timestamp,
    int? replyCount,
    Map<String, List<String>>? reactions,
  }) {
    return FeedComment(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      authorStudentId: authorStudentId ?? this.authorStudentId,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      authorRole: authorRole ?? this.authorRole,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      replyCount: replyCount ?? this.replyCount,
      reactions: reactions ?? this.reactions,
    );
  }

  factory FeedComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return FeedComment(
      id: doc.id,
      authorName: data['authorName']?.toString() ?? 'EWU Student',
      authorEmail: data['authorEmail']?.toString() ?? '',
      authorStudentId: data['authorStudentId']?.toString() ?? '',
      authorPhotoUrl: data['authorPhotoUrl']?.toString() ?? '',
      authorRole: data['authorRole']?.toString() ?? 'user',
      body: data['body']?.toString() ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
      replyCount: (data['replyCount'] as num?)?.toInt() ?? 0,
      reactions: _parseReactionMap(data['reactions']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'authorName': authorName,
      'authorEmail': authorEmail,
      'authorStudentId': authorStudentId,
      'authorPhotoUrl': authorPhotoUrl,
      'authorRole': authorRole,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'replyCount': replyCount,
      'reactions': reactions,
    };
  }
}

class FeedReply {
  const FeedReply({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    required this.authorStudentId,
    required this.authorPhotoUrl,
    required this.authorRole,
    required this.body,
    required this.timestamp,
    required this.reactions,
  });

  final String id;
  final String authorName;
  final String authorEmail;
  final String authorStudentId;
  final String authorPhotoUrl;
  final String authorRole;
  final String body;
  final DateTime timestamp;
  final Map<String, List<String>> reactions;

  int reactionCount(String reactionType) {
    return reactions[reactionType]?.length ?? 0;
  }

  bool reactedBy(String email, String reactionType) {
    return reactions[reactionType]?.contains(email.trim().toLowerCase()) ??
        false;
  }

  FeedReply copyWith({
    String? id,
    String? authorName,
    String? authorEmail,
    String? authorStudentId,
    String? authorPhotoUrl,
    String? authorRole,
    String? body,
    DateTime? timestamp,
    Map<String, List<String>>? reactions,
  }) {
    return FeedReply(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      authorStudentId: authorStudentId ?? this.authorStudentId,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      authorRole: authorRole ?? this.authorRole,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      reactions: reactions ?? this.reactions,
    );
  }

  factory FeedReply.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return FeedReply(
      id: doc.id,
      authorName: data['authorName']?.toString() ?? 'EWU Student',
      authorEmail: data['authorEmail']?.toString() ?? '',
      authorStudentId: data['authorStudentId']?.toString() ?? '',
      authorPhotoUrl: data['authorPhotoUrl']?.toString() ?? '',
      authorRole: data['authorRole']?.toString() ?? 'user',
      body: data['body']?.toString() ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
      reactions: _parseReactionMap(data['reactions']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'authorName': authorName,
      'authorEmail': authorEmail,
      'authorStudentId': authorStudentId,
      'authorPhotoUrl': authorPhotoUrl,
      'authorRole': authorRole,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'reactions': reactions,
    };
  }
}

DateTime _parseTimestamp(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

List<String> _stringList(Object? raw) {
  return List<String>.from(raw as List? ?? const <String>[])
      .map((String value) => value.trim().toLowerCase())
      .where((String value) => value.isNotEmpty)
      .toList();
}

Map<String, List<String>> _parseReactionMap(
  Object? raw, {
  List<String> fallbackLikes = const <String>[],
}) {
  final Map<String, List<String>> normalized = <String, List<String>>{
    'like': <String>[...fallbackLikes],
    'heart': <String>[],
    'laugh': <String>[],
  };
  if (raw is! Map) {
    return normalized;
  }
  for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
    final String key = entry.key?.toString().trim().toLowerCase() ?? '';
    if (!FeedPost.reactionTypes.contains(key)) {
      continue;
    }
    normalized[key] = _stringList(entry.value);
  }
  return normalized;
}
