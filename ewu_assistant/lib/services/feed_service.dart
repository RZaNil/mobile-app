import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/feed_post.dart';
import '../models/gallery_post.dart';

class FeedService {
  static const String campusFeedCollection = 'campus_feed';
  static const String campusGalleryCollection = 'campus_gallery';
  static const String commentsCollection = 'comments';
  static const String repliesCollection = 'replies';

  bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseFirestore get _firestore {
    if (Firebase.apps.isEmpty) {
      throw Exception(
        'Firebase is not configured yet. Complete the Firebase setup to use campus features.',
      );
    }
    return FirebaseFirestore.instance;
  }

  Stream<List<FeedPost>> getPosts() {
    if (!isAvailable) {
      return Stream<List<FeedPost>>.value(const <FeedPost>[]);
    }

    return _firestore
        .collection(campusFeedCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map(FeedPost.fromFirestore).toList();
        });
  }

  Future<void> createPost(FeedPost post) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection = _firestore
          .collection(campusFeedCollection);
      final DocumentReference<Map<String, dynamic>> doc = post.id.isEmpty
          ? collection.doc()
          : collection.doc(post.id);
      final FeedPost savedPost = post.copyWith(
        id: doc.id,
        likes: post.reactionCount('like'),
        likedBy: post.reactions['like'] ?? const <String>[],
      );
      await doc.set(savedPost.toMap());
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to publish the post right now.',
        ),
      );
    }
  }

  Future<void> updatePost(FeedPost post) async {
    if (post.id.trim().isEmpty) {
      throw Exception('That post is unavailable right now.');
    }

    try {
      final FeedPost updatedPost = post.copyWith(
        likes: post.reactionCount('like'),
        likedBy: post.reactions['like'] ?? const <String>[],
      );
      await _firestore
          .collection(campusFeedCollection)
          .doc(post.id)
          .set(updatedPost.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to update the post right now.',
        ),
      );
    }
  }

  Future<void> toggleReaction(
    String postId,
    String reaction,
    String email,
  ) async {
    final String normalizedEmail = _requireSignedInEmail(email);
    final String normalizedReaction = _normalizeReaction(reaction);
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(campusFeedCollection)
        .doc(postId);

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(ref);
        if (!snapshot.exists) {
          return;
        }

        final Map<String, List<String>> reactions = _reactionMapForSnapshot(
          snapshot.data(),
        );
        final bool alreadySelected =
            reactions[normalizedReaction]?.contains(normalizedEmail) ?? false;
        for (final String type in FeedPost.reactionTypes) {
          reactions[type]!.remove(normalizedEmail);
        }
        if (!alreadySelected) {
          reactions[normalizedReaction]!.add(normalizedEmail);
        }

        transaction.update(ref, <String, dynamic>{
          'reactions': reactions,
          'likedBy': reactions['like'],
          'likes': reactions['like']!.length,
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

  Future<void> toggleLike(String postId, String email) {
    return toggleReaction(postId, 'like', email);
  }

  Future<void> deletePost(String postId) async {
    try {
      final DocumentReference<Map<String, dynamic>> postRef = _firestore
          .collection(campusFeedCollection)
          .doc(postId);
      final QuerySnapshot<Map<String, dynamic>> comments = await postRef
          .collection(commentsCollection)
          .get();
      final WriteBatch batch = _firestore.batch();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> comment
          in comments.docs) {
        final QuerySnapshot<Map<String, dynamic>> replies = await comment
            .reference
            .collection(repliesCollection)
            .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> reply
            in replies.docs) {
          batch.delete(reply.reference);
        }
        batch.delete(comment.reference);
      }

      batch.delete(postRef);
      await batch.commit();
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to delete the post right now.',
        ),
      );
    }
  }

  Stream<List<FeedComment>> getComments(String postId) {
    if (!isAvailable) {
      return Stream<List<FeedComment>>.value(const <FeedComment>[]);
    }

    return _firestore
        .collection(campusFeedCollection)
        .doc(postId)
        .collection(commentsCollection)
        .orderBy('timestamp')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map(FeedComment.fromFirestore).toList();
        });
  }

  Future<void> addComment(String postId, FeedComment comment) async {
    try {
      final DocumentReference<Map<String, dynamic>> postRef = _firestore
          .collection(campusFeedCollection)
          .doc(postId);
      final CollectionReference<Map<String, dynamic>> commentsRef = postRef
          .collection(commentsCollection);
      final DocumentReference<Map<String, dynamic>> commentRef =
          comment.id.isEmpty ? commentsRef.doc() : commentsRef.doc(comment.id);

      final WriteBatch batch = _firestore.batch();
      batch.set(commentRef, comment.copyWith(id: commentRef.id).toMap());
      batch.update(postRef, <String, dynamic>{
        'replyCount': FieldValue.increment(1),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to send the comment right now.',
        ),
      );
    }
  }

  Future<void> deleteComment(String postId, FeedComment comment) async {
    try {
      final DocumentReference<Map<String, dynamic>> postRef = _firestore
          .collection(campusFeedCollection)
          .doc(postId);
      final DocumentReference<Map<String, dynamic>> commentRef = postRef
          .collection(commentsCollection)
          .doc(comment.id);
      final QuerySnapshot<Map<String, dynamic>> replies = await commentRef
          .collection(repliesCollection)
          .get();
      final WriteBatch batch = _firestore.batch();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> reply
          in replies.docs) {
        batch.delete(reply.reference);
      }
      batch.delete(commentRef);
      batch.update(postRef, <String, dynamic>{
        'replyCount': FieldValue.increment(-1),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to delete the comment right now.',
        ),
      );
    }
  }

  Future<void> toggleCommentReaction({
    required String postId,
    required String commentId,
    required String reaction,
    required String email,
  }) async {
    final String normalizedEmail = _requireSignedInEmail(email);
    final String normalizedReaction = _normalizeReaction(reaction);
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(campusFeedCollection)
        .doc(postId)
        .collection(commentsCollection)
        .doc(commentId);

    await _toggleReactionOnDocument(
      ref: ref,
      reaction: normalizedReaction,
      actorKey: normalizedEmail,
      fallback: 'Unable to update the comment reaction right now.',
    );
  }

  Stream<List<FeedReply>> getReplies(String postId, String commentId) {
    if (!isAvailable) {
      return Stream<List<FeedReply>>.value(const <FeedReply>[]);
    }

    return _firestore
        .collection(campusFeedCollection)
        .doc(postId)
        .collection(commentsCollection)
        .doc(commentId)
        .collection(repliesCollection)
        .orderBy('timestamp')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map(FeedReply.fromFirestore).toList();
        });
  }

  Future<void> addReply(
    String postId,
    String commentId,
    FeedReply reply,
  ) async {
    try {
      final DocumentReference<Map<String, dynamic>> commentRef = _firestore
          .collection(campusFeedCollection)
          .doc(postId)
          .collection(commentsCollection)
          .doc(commentId);
      final CollectionReference<Map<String, dynamic>> repliesRef = commentRef
          .collection(repliesCollection);
      final DocumentReference<Map<String, dynamic>> replyRef = reply.id.isEmpty
          ? repliesRef.doc()
          : repliesRef.doc(reply.id);

      final WriteBatch batch = _firestore.batch();
      batch.set(replyRef, reply.copyWith(id: replyRef.id).toMap());
      batch.update(commentRef, <String, dynamic>{
        'replyCount': FieldValue.increment(1),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to send the reply right now.',
        ),
      );
    }
  }

  Future<void> deleteReply({
    required String postId,
    required String commentId,
    required FeedReply reply,
  }) async {
    try {
      final DocumentReference<Map<String, dynamic>> commentRef = _firestore
          .collection(campusFeedCollection)
          .doc(postId)
          .collection(commentsCollection)
          .doc(commentId);
      final WriteBatch batch = _firestore.batch();
      batch.delete(commentRef.collection(repliesCollection).doc(reply.id));
      batch.update(commentRef, <String, dynamic>{
        'replyCount': FieldValue.increment(-1),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to delete the reply right now.',
        ),
      );
    }
  }

  Future<void> toggleReplyReaction({
    required String postId,
    required String commentId,
    required String replyId,
    required String reaction,
    required String email,
  }) async {
    final String normalizedEmail = _requireSignedInEmail(email);
    final String normalizedReaction = _normalizeReaction(reaction);
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(campusFeedCollection)
        .doc(postId)
        .collection(commentsCollection)
        .doc(commentId)
        .collection(repliesCollection)
        .doc(replyId);

    await _toggleReactionOnDocument(
      ref: ref,
      reaction: normalizedReaction,
      actorKey: normalizedEmail,
      fallback: 'Unable to update the reply reaction right now.',
    );
  }

  Stream<List<GalleryPost>> getGalleryPosts() {
    if (!isAvailable) {
      return Stream<List<GalleryPost>>.value(const <GalleryPost>[]);
    }

    return _firestore
        .collection(campusGalleryCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map(GalleryPost.fromFirestore).toList();
        });
  }

  Future<void> createGalleryPost(GalleryPost post) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection = _firestore
          .collection(campusGalleryCollection);
      final DocumentReference<Map<String, dynamic>> doc = post.id.isEmpty
          ? collection.doc()
          : collection.doc(post.id);
      await doc.set(post.copyWith(id: doc.id).toMap());
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to publish the photo right now.',
        ),
      );
    }
  }

  Future<void> deleteGalleryPost(String postId) async {
    try {
      await _firestore.collection(campusGalleryCollection).doc(postId).delete();
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to remove the photo right now.',
        ),
      );
    }
  }

  Future<void> toggleGalleryLike(String postId, String email) async {
    final String normalizedEmail = _requireSignedInEmail(email);
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(campusGalleryCollection)
        .doc(postId);

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(ref);
        if (!snapshot.exists) {
          return;
        }

        final List<String> likedBy = List<String>.from(
          snapshot.data()?['likedBy'] as List? ?? const <String>[],
        );
        if (likedBy.contains(normalizedEmail)) {
          likedBy.remove(normalizedEmail);
        } else {
          likedBy.add(normalizedEmail);
        }

        transaction.update(ref, <String, dynamic>{'likedBy': likedBy});
      });
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to update the like right now.',
        ),
      );
    }
  }

  Future<void> _toggleReactionOnDocument({
    required DocumentReference<Map<String, dynamic>> ref,
    required String reaction,
    required String actorKey,
    required String fallback,
  }) async {
    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(ref);
        if (!snapshot.exists) {
          return;
        }

        final Map<String, List<String>> reactions = _reactionMapForSnapshot(
          snapshot.data(),
        );
        final bool alreadySelected =
            reactions[reaction]?.contains(actorKey) ?? false;
        for (final String type in FeedPost.reactionTypes) {
          reactions[type]!.remove(actorKey);
        }
        if (!alreadySelected) {
          reactions[reaction]!.add(actorKey);
        }
        transaction.update(ref, <String, dynamic>{'reactions': reactions});
      });
    } on FirebaseException catch (error) {
      throw Exception(_mapFirestoreError(error, fallback: fallback));
    }
  }

  Map<String, List<String>> _reactionMapForSnapshot(
    Map<String, dynamic>? data,
  ) {
    final List<String> fallbackLikes = List<String>.from(
      data?['likedBy'] as List? ?? const <String>[],
    ).map((String value) => value.trim().toLowerCase()).toList();
    final Map<String, List<String>> normalized = <String, List<String>>{
      'like': <String>[...fallbackLikes],
      'heart': <String>[],
      'laugh': <String>[],
    };
    final Object? raw = data?['reactions'];
    if (raw is Map) {
      for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
        final String key = entry.key?.toString().trim().toLowerCase() ?? '';
        if (!FeedPost.reactionTypes.contains(key)) {
          continue;
        }
        normalized[key] = List<String>.from(
          entry.value as List? ?? const <String>[],
        ).map((String value) => value.trim().toLowerCase()).toList();
      }
    }
    return normalized;
  }

  String _normalizeReaction(String reaction) {
    final String normalizedReaction = reaction.trim().toLowerCase();
    if (!FeedPost.reactionTypes.contains(normalizedReaction)) {
      throw Exception('That reaction is unavailable right now.');
    }
    return normalizedReaction;
  }

  String _requireSignedInEmail(String email) {
    final String normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw Exception('Please sign in again to continue.');
    }
    return normalizedEmail;
  }

  String _mapFirestoreError(
    FirebaseException error, {
    required String fallback,
  }) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to complete that action.';
      case 'unavailable':
        return 'The campus service is temporarily unavailable. Please try again.';
      case 'not-found':
        return 'That item is no longer available.';
      default:
        return fallback;
    }
  }
}
