import 'package:cloud_firestore/cloud_firestore.dart';

class DirectChatThread {
  const DirectChatThread({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageImageUrl,
    required this.lastSeenBy,
    required this.lastMessageAt,
    required this.lastSenderUid,
  });

  final String id;
  final List<String> participants;
  final String lastMessage;
  final String lastMessageType;
  final String lastMessageImageUrl;
  final List<String> lastSeenBy;
  final DateTime? lastMessageAt;
  final String lastSenderUid;

  bool includes(String uid) => participants.contains(uid);

  bool isUnreadFor(String currentUid) {
    return lastSenderUid.isNotEmpty &&
        lastSenderUid != currentUid &&
        !lastSeenBy.contains(currentUid);
  }

  String previewText() {
    if (lastMessageType == DirectChatMessage.imageType &&
        lastMessageImageUrl.isNotEmpty &&
        lastMessage.trim().isEmpty) {
      return 'Photo';
    }
    if (lastMessageType == DirectChatMessage.deletedType) {
      return lastMessage.isEmpty ? 'Message removed' : lastMessage;
    }
    return lastMessage.trim().isEmpty
        ? 'Say hello to start chatting.'
        : lastMessage;
  }

  String? otherParticipantId(String currentUid) {
    for (final String uid in participants) {
      if (uid != currentUid) {
        return uid;
      }
    }
    return null;
  }

  factory DirectChatThread.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return DirectChatThread(
      id: doc.id,
      participants: _stringList(data['participants']),
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastMessageType:
          data['lastMessageType']?.toString() ?? DirectChatMessage.textType,
      lastMessageImageUrl: data['lastMessageImageUrl']?.toString() ?? '',
      lastSeenBy: _stringList(data['lastSeenBy']),
      lastMessageAt: _parseNullableDate(data['lastMessageAt']),
      lastSenderUid: data['lastSenderUid']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageImageUrl': lastMessageImageUrl,
      'lastSeenBy': lastSeenBy,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastSenderUid': lastSenderUid,
    };
  }

  static DateTime? _parseNullableDate(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class DirectChatMessage {
  const DirectChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    required this.imageUrl,
    required this.type,
    required this.createdAt,
    required this.seenBy,
    required this.reactions,
    required this.isDeleted,
  });

  static const String textType = 'text';
  static const String imageType = 'image';
  static const String deletedType = 'deleted';

  static const List<String> supportedReactions = <String>[
    'like',
    'heart',
    'laugh',
  ];

  final String id;
  final String senderUid;
  final String senderName;
  final String text;
  final String imageUrl;
  final String type;
  final DateTime createdAt;
  final List<String> seenBy;
  final Map<String, List<String>> reactions;
  final bool isDeleted;

  bool get hasText => text.trim().isNotEmpty;

  bool get hasImage => imageUrl.trim().isNotEmpty;

  bool reactedBy(String currentUid, String reactionType) {
    return reactions[reactionType]?.contains(currentUid) ?? false;
  }

  int reactionCount(String reactionType) {
    return reactions[reactionType]?.length ?? 0;
  }

  factory DirectChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return DirectChatMessage(
      id: doc.id,
      senderUid: data['senderUid']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'EWU Student',
      text: data['text']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      type: data['type']?.toString() ?? textType,
      createdAt: _parseDate(data['createdAt']),
      seenBy: _stringList(data['seenBy']),
      reactions: _parseReactionMap(data['reactions']),
      isDeleted: data['isDeleted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'senderUid': senderUid,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'seenBy': seenBy,
      'reactions': reactions,
      'isDeleted': isDeleted,
    };
  }

  static DateTime _parseDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

List<String> _stringList(Object? raw) {
  return List<String>.from(raw as List? ?? const <String>[])
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList();
}

Map<String, List<String>> _parseReactionMap(Object? raw) {
  final Map<String, List<String>> normalized = <String, List<String>>{};
  if (raw is! Map) {
    return normalized;
  }

  for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
    final String key = entry.key?.toString().trim() ?? '';
    if (key.isEmpty) {
      continue;
    }
    normalized[key] = _stringList(entry.value);
  }
  return normalized;
}
