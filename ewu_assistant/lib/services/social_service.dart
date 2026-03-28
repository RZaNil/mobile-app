import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/direct_chat.dart';
import '../models/student_profile.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class MessagesDashboardData {
  const MessagesDashboardData({
    required this.currentUid,
    required this.users,
    required this.chats,
  });

  final String currentUid;
  final List<UserDirectoryRecord> users;
  final List<DirectChatThread> chats;

  factory MessagesDashboardData.empty({required String currentUid}) {
    return MessagesDashboardData(
      currentUid: currentUid,
      users: const <UserDirectoryRecord>[],
      chats: const <DirectChatThread>[],
    );
  }

  Map<String, UserDirectoryRecord> get usersByUid {
    return <String, UserDirectoryRecord>{
      for (final UserDirectoryRecord record in users) record.uid: record,
    };
  }

  List<UserDirectoryRecord> get directoryUsers {
    final List<UserDirectoryRecord> visibleUsers = users.where((
      UserDirectoryRecord record,
    ) {
      return record.uid != currentUid;
    }).toList();
    visibleUsers.sort((UserDirectoryRecord a, UserDirectoryRecord b) {
      return a.profile.name.toLowerCase().compareTo(
        b.profile.name.toLowerCase(),
      );
    });
    return visibleUsers;
  }

  UserDirectoryRecord? userForId(String uid) => usersByUid[uid];
}

class SocialService {
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';

  final NotificationService _notificationService = NotificationService();

  bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseFirestore get _firestore {
    if (Firebase.apps.isEmpty) {
      throw Exception(
        'Firebase is unavailable right now. Please restart the app and try again.',
      );
    }
    return FirebaseFirestore.instance;
  }

  Stream<MessagesDashboardData> watchDashboard(String currentUid) {
    final String normalizedUid = currentUid.trim();
    if (!isAvailable || normalizedUid.isEmpty) {
      return Stream<MessagesDashboardData>.value(
        MessagesDashboardData.empty(currentUid: normalizedUid),
      );
    }

    late StreamController<MessagesDashboardData> controller;
    final List<StreamSubscription<dynamic>> subscriptions =
        <StreamSubscription<dynamic>>[];

    List<UserDirectoryRecord> users = const <UserDirectoryRecord>[];
    List<DirectChatThread> chats = const <DirectChatThread>[];

    void emit() {
      if (controller.isClosed) {
        return;
      }
      controller.add(
        MessagesDashboardData(
          currentUid: normalizedUid,
          users: users,
          chats: chats,
        ),
      );
    }

    controller = StreamController<MessagesDashboardData>(
      onListen: () {
        unawaited(AuthService.ensureCurrentUserProfile());
        emit();

        subscriptions.add(
          AuthService.watchUsers().listen(
            (List<UserDirectoryRecord> value) {
              users = value;
              emit();
            },
            onError: (_) {
              users = const <UserDirectoryRecord>[];
              emit();
            },
          ),
        );

        subscriptions.add(
          _firestore
              .collection(chatsCollection)
              .where('participants', arrayContains: normalizedUid)
              .snapshots()
              .listen(
                (QuerySnapshot<Map<String, dynamic>> snapshot) {
                  chats =
                      snapshot.docs.map(DirectChatThread.fromFirestore).toList()
                        ..sort((DirectChatThread a, DirectChatThread b) {
                          final DateTime first =
                              a.lastMessageAt ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          final DateTime second =
                              b.lastMessageAt ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          return second.compareTo(first);
                        });
                  emit();
                },
                onError: (_) {
                  chats = const <DirectChatThread>[];
                  emit();
                },
              ),
        );
      },
      onCancel: () async {
        for (final StreamSubscription<dynamic> subscription in subscriptions) {
          await subscription.cancel();
        }
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }

  Stream<List<DirectChatMessage>> watchMessages(String chatId) {
    final String normalizedChatId = chatId.trim();
    if (!isAvailable || normalizedChatId.isEmpty) {
      return Stream<List<DirectChatMessage>>.value(const <DirectChatMessage>[]);
    }

    return _firestore
        .collection(chatsCollection)
        .doc(normalizedChatId)
        .collection(messagesCollection)
        .orderBy('createdAt')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map(DirectChatMessage.fromFirestore).toList();
        });
  }

  static String chatIdForUsers(String firstUid, String secondUid) {
    return _chatId(firstUid, secondUid);
  }

  Future<UserDirectoryRecord?> fetchUserByUid(String uid) async {
    final String normalizedUid = uid.trim();
    if (!isAvailable || normalizedUid.isEmpty) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(usersCollection)
          .doc(normalizedUid)
          .get();
      if (!snapshot.exists) {
        return null;
      }

      StudentProfile profile = StudentProfile.fromJson(
        snapshot.data() ?? <String, dynamic>{},
      );
      if (profile.email.isEmpty) {
        return null;
      }
      final String normalizedEmail = profile.email.trim().toLowerCase();
      if (normalizedEmail == AuthService.superAdminEmail) {
        profile = profile.copyWith(role: StudentProfile.superAdminRole);
      } else if (normalizedEmail == AuthService.specialAllowedUserEmail) {
        profile = profile.copyWith(role: StudentProfile.userRole);
      }
      return UserDirectoryRecord(uid: snapshot.id, profile: profile);
    } on FirebaseException {
      return null;
    }
  }

  Future<String> ensureDirectChat({
    required String otherUid,
    required StudentProfile otherProfile,
  }) async {
    final _SignedInContext current = await _requireSignedInContext();
    final String normalizedOtherUid = otherUid.trim();

    if (normalizedOtherUid.isEmpty || normalizedOtherUid == current.uid) {
      throw Exception('That chat is unavailable right now.');
    }

    final String chatId = _chatId(current.uid, normalizedOtherUid);
    final DocumentReference<Map<String, dynamic>> chatRef = _firestore
        .collection(chatsCollection)
        .doc(chatId);

    try {
      await chatRef.set(<String, dynamic>{
        'participants': _sortedUsers(current.uid, normalizedOtherUid),
        'lastMessage': '',
        'lastMessageType': DirectChatMessage.textType,
        'lastMessageImageUrl': '',
        'lastSeenBy': <String>[current.uid],
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderUid': '',
      }, SetOptions(merge: true));

      return chatId;
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to open the chat with ${otherProfile.firstName}.',
        ),
      );
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required String otherUid,
    String text = '',
    String imageUrl = '',
  }) async {
    final _SignedInContext current = await _requireSignedInContext();
    final String trimmedText = text.trim();
    final String trimmedImageUrl = imageUrl.trim();
    final String normalizedOtherUid = otherUid.trim();
    if (trimmedText.isEmpty && trimmedImageUrl.isEmpty) {
      return;
    }
    if (normalizedOtherUid.isEmpty || normalizedOtherUid == current.uid) {
      throw Exception('That conversation is unavailable right now.');
    }

    final DocumentReference<Map<String, dynamic>> chatRef = _firestore
        .collection(chatsCollection)
        .doc(chatId);

    try {
      final String messageType = trimmedImageUrl.isNotEmpty
          ? DirectChatMessage.imageType
          : DirectChatMessage.textType;
      final String preview = trimmedText.isNotEmpty ? trimmedText : 'Photo';
      final DocumentReference<Map<String, dynamic>> messageRef = chatRef
          .collection(messagesCollection)
          .doc();

      final WriteBatch batch = _firestore.batch();
      batch.set(messageRef, <String, dynamic>{
        'senderUid': current.uid,
        'senderName': current.profile.name,
        'text': trimmedText,
        'imageUrl': trimmedImageUrl,
        'type': messageType,
        'createdAt': FieldValue.serverTimestamp(),
        'seenBy': <String>[current.uid],
        'reactions': <String, List<String>>{},
        'isDeleted': false,
      });
      batch.set(chatRef, <String, dynamic>{
        'participants': _sortedUsers(current.uid, normalizedOtherUid),
        'lastMessage': preview,
        'lastMessageType': messageType,
        'lastMessageImageUrl': trimmedImageUrl,
        'lastSeenBy': <String>[current.uid],
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderUid': current.uid,
      }, SetOptions(merge: true));
      await batch.commit();

      await _notificationService.createForUsers(
        userIds: <String>[normalizedOtherUid],
        type: 'message_activity',
        title: 'New message from ${current.profile.firstName}',
        body: trimmedText.isNotEmpty ? trimmedText : 'Sent a photo.',
        relatedId: chatId,
        senderUid: current.uid,
        senderName: current.profile.name,
      );
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to send the message right now.',
        ),
      );
    }
  }

  Future<void> deleteOwnMessage({
    required String chatId,
    required DirectChatMessage message,
  }) async {
    final _SignedInContext current = await _requireSignedInContext();
    if (message.senderUid != current.uid) {
      throw Exception('You can only remove your own messages.');
    }

    final DocumentReference<Map<String, dynamic>> messageRef = _firestore
        .collection(chatsCollection)
        .doc(chatId)
        .collection(messagesCollection)
        .doc(message.id);

    try {
      await messageRef.set(<String, dynamic>{
        'text': '',
        'imageUrl': '',
        'type': DirectChatMessage.deletedType,
        'isDeleted': true,
        'reactions': <String, List<String>>{},
        'seenBy': FieldValue.arrayUnion(<String>[current.uid]),
      }, SetOptions(merge: true));
      await _syncChatPreview(chatId);
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to remove that message right now.',
        ),
      );
    }
  }

  Future<void> toggleMessageReaction({
    required String chatId,
    required String messageId,
    required String reaction,
  }) async {
    final _SignedInContext current = await _requireSignedInContext();
    final String normalizedReaction = reaction.trim().toLowerCase();
    if (!DirectChatMessage.supportedReactions.contains(normalizedReaction)) {
      throw Exception('That reaction is unavailable right now.');
    }

    final DocumentReference<Map<String, dynamic>> messageRef = _firestore
        .collection(chatsCollection)
        .doc(chatId)
        .collection(messagesCollection)
        .doc(messageId);

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(messageRef);
        if (!snapshot.exists) {
          throw Exception('That message is no longer available.');
        }

        final DirectChatMessage message = DirectChatMessage.fromFirestore(
          snapshot,
        );
        final Map<String, List<String>> reactions = <String, List<String>>{
          for (final String type in DirectChatMessage.supportedReactions)
            type: List<String>.from(
              message.reactions[type] ?? const <String>[],
            ),
        };

        final bool alreadySelected =
            reactions[normalizedReaction]?.contains(current.uid) ?? false;
        for (final String type in DirectChatMessage.supportedReactions) {
          reactions[type]!.remove(current.uid);
        }
        if (!alreadySelected) {
          reactions[normalizedReaction]!.add(current.uid);
        }

        transaction.update(messageRef, <String, dynamic>{
          'reactions': reactions,
        });
      });
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to update the reaction right now.',
        ),
      );
    }
  }

  Future<void> markChatSeen(String chatId) async {
    final String? currentUid = AuthService.currentUser?.uid;
    if (!isAvailable || currentUid == null || currentUid.isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> chatRef = _firestore
        .collection(chatsCollection)
        .doc(chatId);

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await chatRef
          .collection(messagesCollection)
          .orderBy('createdAt', descending: true)
          .limit(75)
          .get();

      final WriteBatch batch = _firestore.batch();
      int updateCount = 0;

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String senderUid = data['senderUid']?.toString() ?? '';
        final List<String> seenBy = List<String>.from(
          data['seenBy'] as List? ?? const <String>[],
        );
        if (senderUid == currentUid || seenBy.contains(currentUid)) {
          continue;
        }
        batch.update(doc.reference, <String, dynamic>{
          'seenBy': FieldValue.arrayUnion(<String>[currentUid]),
        });
        updateCount++;
      }

      if (updateCount > 0) {
        await batch.commit();
      }

      await chatRef.set(<String, dynamic>{
        'lastSeenBy': FieldValue.arrayUnion(<String>[currentUid]),
      }, SetOptions(merge: true));
    } on FirebaseException {
      // Best-effort only.
    }
  }

  Future<void> _syncChatPreview(String chatId) async {
    final DocumentReference<Map<String, dynamic>> chatRef = _firestore
        .collection(chatsCollection)
        .doc(chatId);

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await chatRef
          .collection(messagesCollection)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        await chatRef.set(<String, dynamic>{
          'lastMessage': '',
          'lastMessageType': DirectChatMessage.textType,
          'lastMessageImageUrl': '',
          'lastSeenBy': const <String>[],
          'lastSenderUid': '',
        }, SetOptions(merge: true));
        return;
      }

      final DirectChatMessage message = DirectChatMessage.fromFirestore(
        snapshot.docs.first,
      );
      await chatRef.set(<String, dynamic>{
        'lastMessage': _previewForMessage(message),
        'lastMessageType': message.type,
        'lastMessageImageUrl': message.imageUrl,
        'lastSeenBy': message.seenBy,
        'lastMessageAt': Timestamp.fromDate(message.createdAt),
        'lastSenderUid': message.senderUid,
      }, SetOptions(merge: true));
    } on FirebaseException {
      // Best-effort only.
    }
  }

  Future<_SignedInContext> _requireSignedInContext() async {
    final String? uid = AuthService.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Please sign in again to continue.');
    }

    await AuthService.ensureCurrentUserProfile();
    final StudentProfile? profile = await AuthService.getProfile();
    if (profile == null || profile.email.isEmpty) {
      throw Exception('We could not load your student profile right now.');
    }

    return _SignedInContext(uid: uid, profile: profile);
  }

  static String _previewForMessage(DirectChatMessage message) {
    if (message.type == DirectChatMessage.deletedType) {
      return 'Message removed';
    }
    if (message.text.trim().isNotEmpty) {
      return message.text.trim();
    }
    if (message.imageUrl.trim().isNotEmpty) {
      return 'Photo';
    }
    return '';
  }

  static String _chatId(String firstUid, String secondUid) {
    return 'chat_${_pairKey(firstUid, secondUid)}';
  }

  static String _pairKey(String firstUid, String secondUid) {
    final List<String> users = _sortedUsers(firstUid, secondUid);
    return '${users[0]}_${users[1]}';
  }

  static List<String> _sortedUsers(String firstUid, String secondUid) {
    final List<String> users = <String>[firstUid, secondUid]..sort();
    return users;
  }

  String _mapFirestoreError(
    FirebaseException error, {
    required String fallback,
  }) {
    switch (error.code) {
      case 'permission-denied':
        return 'Messaging is blocked by your Firestore rules. Allow chat and message access for signed-in participants.';
      case 'unavailable':
        return 'The messaging service is temporarily unavailable. Please try again.';
      case 'not-found':
        return 'That conversation is no longer available.';
      default:
        return fallback;
    }
  }
}

class _SignedInContext {
  const _SignedInContext({required this.uid, required this.profile});

  final String uid;
  final StudentProfile profile;
}
