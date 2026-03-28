import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/marketplace_post.dart';
import '../models/note_item.dart';
import '../models/workplace_post.dart';

class ServicesHubService {
  static const String notesCollection = 'notes';
  static const String workplacePostsCollection = 'workplace_posts';
  static const String marketplacePostsCollection = 'marketplace_posts';

  bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseFirestore get _firestore {
    if (Firebase.apps.isEmpty) {
      throw Exception(
        'Firebase is unavailable right now. Please restart the app and try again.',
      );
    }
    return FirebaseFirestore.instance;
  }

  Stream<List<NoteItem>> getNotes() {
    if (!isAvailable) {
      return Stream<List<NoteItem>>.value(const <NoteItem>[]);
    }

    return _firestore
        .collection(notesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map(NoteItem.fromFirestore).toList();
        });
  }

  Future<void> createNote(NoteItem note) async {
    await saveNote(note);
  }

  Future<void> saveNote(NoteItem note) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection = _firestore
          .collection(notesCollection);
      final DocumentReference<Map<String, dynamic>> doc = note.id.isEmpty
          ? collection.doc()
          : collection.doc(note.id);
      await doc.set(note.copyWith(id: doc.id).toMap());
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to save the note right now.',
        ),
      );
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _firestore.collection(notesCollection).doc(noteId).delete();
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to delete the note right now.',
        ),
      );
    }
  }

  Stream<List<WorkplacePost>> getWorkplacePosts() {
    if (!isAvailable) {
      return Stream<List<WorkplacePost>>.value(const <WorkplacePost>[]);
    }

    return _firestore
        .collection(workplacePostsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map(WorkplacePost.fromFirestore).toList();
        });
  }

  Future<void> createWorkplacePost(WorkplacePost post) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection = _firestore
          .collection(workplacePostsCollection);
      final DocumentReference<Map<String, dynamic>> doc = post.id.isEmpty
          ? collection.doc()
          : collection.doc(post.id);
      await doc.set(post.copyWith(id: doc.id).toMap());
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to publish the workplace post right now.',
        ),
      );
    }
  }

  Future<void> deleteWorkplacePost(String postId) async {
    try {
      await _firestore
          .collection(workplacePostsCollection)
          .doc(postId)
          .delete();
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to delete the workplace post right now.',
        ),
      );
    }
  }

  Stream<List<MarketplacePost>> getMarketplacePosts() {
    if (!isAvailable) {
      return Stream<List<MarketplacePost>>.value(const <MarketplacePost>[]);
    }

    return _firestore
        .collection(marketplacePostsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map(MarketplacePost.fromFirestore).toList();
        });
  }

  Future<void> createMarketplacePost(MarketplacePost post) async {
    try {
      final CollectionReference<Map<String, dynamic>> collection = _firestore
          .collection(marketplacePostsCollection);
      final DocumentReference<Map<String, dynamic>> doc = post.id.isEmpty
          ? collection.doc()
          : collection.doc(post.id);
      await doc.set(post.copyWith(id: doc.id).toMap());
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to publish the marketplace post right now.',
        ),
      );
    }
  }

  Future<void> deleteMarketplacePost(String postId) async {
    try {
      await _firestore
          .collection(marketplacePostsCollection)
          .doc(postId)
          .delete();
    } on FirebaseException catch (error) {
      throw Exception(
        _mapFirestoreError(
          error,
          fallback: 'Unable to delete the marketplace post right now.',
        ),
      );
    }
  }

  String _mapFirestoreError(
    FirebaseException error, {
    required String fallback,
  }) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to complete that action.';
      case 'unavailable':
        return 'The student services hub is temporarily unavailable. Please try again.';
      case 'not-found':
        return 'That item is no longer available.';
      default:
        return fallback;
    }
  }
}
