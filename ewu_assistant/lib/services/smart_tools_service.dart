import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class SmartToolsService {
  static const String _coursePlannerKey = 'smart_course_planner';
  static const String _examCountdownKey = 'smart_exam_countdown';
  static const String _facultyContactsKey = 'smart_faculty_contacts';

  static const String _facultyContactsCollection = 'faculty_contacts';
  static const String _examCountdownsCollection = 'exam_countdowns';

  Future<List<Map<String, dynamic>>> loadCoursePlannerItems() {
    return _readList(_coursePlannerKey);
  }

  Future<void> saveCoursePlannerItems(List<Map<String, dynamic>> items) {
    return _writeList(_coursePlannerKey, items);
  }

  Future<List<Map<String, dynamic>>> loadExamCountdownItems() async {
    final String? uid = _currentUid;
    if (_canUseFirestore(uid)) {
      try {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection(_examCountdownsCollection)
            .where('ownerUid', isEqualTo: uid)
            .get();

        final List<Map<String, dynamic>> items = snapshot.docs.map((
          QueryDocumentSnapshot<Map<String, dynamic>> doc,
        ) {
          return <String, dynamic>{'id': doc.id, ...doc.data()};
        }).toList();
        items.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final DateTime first =
              DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
          final DateTime second =
              DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
          return first.compareTo(second);
        });
        return items;
      } on FirebaseException catch (error) {
        throw Exception(_mapFirestoreError(error, 'exam countdowns'));
      }
    }

    return _readList(_examCountdownKey);
  }

  Future<void> saveExamCountdownItems(List<Map<String, dynamic>> items) async {
    final String? uid = _currentUid;
    if (_canUseFirestore(uid)) {
      try {
        await _syncOwnedCollection(
          collectionName: _examCountdownsCollection,
          ownerUid: uid!,
          items: items,
        );
        return;
      } on FirebaseException catch (error) {
        throw Exception(_mapFirestoreError(error, 'exam countdowns'));
      }
    }

    await _writeList(_examCountdownKey, items);
  }

  Future<List<Map<String, dynamic>>> loadFacultyContacts() async {
    final String? uid = _currentUid;
    if (_canUseFirestore(uid)) {
      try {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection(_facultyContactsCollection)
            .where('ownerUid', isEqualTo: uid)
            .get();

        final List<Map<String, dynamic>> items = snapshot.docs.map((
          QueryDocumentSnapshot<Map<String, dynamic>> doc,
        ) {
          return <String, dynamic>{'id': doc.id, ...doc.data()};
        }).toList();
        items.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          return (a['name']?.toString().toLowerCase() ?? '').compareTo(
            b['name']?.toString().toLowerCase() ?? '',
          );
        });
        return items;
      } on FirebaseException catch (error) {
        throw Exception(_mapFirestoreError(error, 'faculty contacts'));
      }
    }

    return _readList(_facultyContactsKey);
  }

  Future<void> saveFacultyContacts(List<Map<String, dynamic>> items) async {
    final String? uid = _currentUid;
    if (_canUseFirestore(uid)) {
      try {
        await _syncOwnedCollection(
          collectionName: _facultyContactsCollection,
          ownerUid: uid!,
          items: items,
        );
        return;
      } on FirebaseException catch (error) {
        throw Exception(_mapFirestoreError(error, 'faculty contacts'));
      }
    }

    await _writeList(_facultyContactsKey, items);
  }

  Future<void> _syncOwnedCollection({
    required String collectionName,
    required String ownerUid,
    required List<Map<String, dynamic>> items,
  }) async {
    final CollectionReference<Map<String, dynamic>> collection = _firestore
        .collection(collectionName);
    final QuerySnapshot<Map<String, dynamic>> existingSnapshot =
        await collection.where('ownerUid', isEqualTo: ownerUid).get();

    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
    existingById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in existingSnapshot.docs)
        doc.id: doc,
    };
    final Set<String> desiredIds = items
        .map((Map<String, dynamic> item) => item['id']?.toString().trim() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final WriteBatch batch = _firestore.batch();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in existingSnapshot.docs) {
      if (!desiredIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    for (final Map<String, dynamic> item in items) {
      final String desiredId = item['id']?.toString().trim().isNotEmpty == true
          ? item['id']!.toString().trim()
          : collection.doc().id;

      final Map<String, dynamic> payload = <String, dynamic>{
        ...item,
        'id': desiredId,
        'ownerUid': ownerUid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!existingById.containsKey(desiredId)) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      batch.set(collection.doc(desiredId), payload, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Map<String, dynamic>>[];
      }

      return decoded.whereType<Map>().map((Map entry) {
        return entry.map(
          (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        );
      }).toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  bool _canUseFirestore(String? uid) {
    return Firebase.apps.isNotEmpty && uid != null && uid.isNotEmpty;
  }

  String? get _currentUid => AuthService.currentUser?.uid.trim();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String _mapFirestoreError(FirebaseException error, String subject) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore rules are blocking your $subject right now.';
      case 'unavailable':
        return 'Firebase is temporarily unavailable. Please try again.';
      default:
        return 'Unable to load your $subject right now.';
    }
  }
}
