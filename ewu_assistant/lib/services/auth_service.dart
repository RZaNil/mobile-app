import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_profile.dart';
import 'notification_service.dart';

class RoleConfigData {
  const RoleConfigData({
    required this.superAdminEmail,
    required this.adminEmails,
  });

  final String superAdminEmail;
  final List<String> adminEmails;

  int get adminCount => adminEmails.length;

  bool isAdminEmail(String email) {
    return adminEmails.contains(email.trim().toLowerCase());
  }

  RoleConfigData copyWith({
    String? superAdminEmail,
    List<String>? adminEmails,
  }) {
    return RoleConfigData(
      superAdminEmail: superAdminEmail ?? this.superAdminEmail,
      adminEmails: adminEmails ?? this.adminEmails,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'superAdminEmail': superAdminEmail,
      'adminEmails': adminEmails,
    };
  }

  factory RoleConfigData.fromJson(
    Map<String, dynamic> json, {
    required String fallbackSuperAdminEmail,
  }) {
    final List<String> adminEmails = <String>[];
    final Object? rawAdminEmails = json['adminEmails'];
    if (rawAdminEmails is List) {
      for (final Object? value in rawAdminEmails) {
        final String email = value?.toString().trim().toLowerCase() ?? '';
        if (email.isEmpty ||
            email == fallbackSuperAdminEmail ||
            email == AuthService.specialAllowedUserEmail ||
            adminEmails.contains(email)) {
          continue;
        }
        adminEmails.add(email);
        if (adminEmails.length == AuthService.maxAdminCount) {
          break;
        }
      }
    }

    final String superAdminEmail =
        json['superAdminEmail']?.toString().trim().toLowerCase() ??
        fallbackSuperAdminEmail;

    return RoleConfigData(
      superAdminEmail: superAdminEmail.isEmpty
          ? fallbackSuperAdminEmail
          : superAdminEmail,
      adminEmails: adminEmails,
    );
  }
}

class UserDirectoryRecord {
  const UserDirectoryRecord({required this.uid, required this.profile});

  final String uid;
  final StudentProfile profile;
}

class AuthService {
  AuthService._();

  static const String superAdminEmail = '2022-3-60-144@std.ewubd.edu';
  static const String specialAllowedUserEmail = 'niloyzani2018@gmail.com';
  static const int maxAdminCount = 3;
  static const String _profileStorageKey = 'student_profile_cache';
  static const String _usersCollection = 'users';
  static const String _legacyProfilesCollection = 'student_profiles';
  static const String _appMetaCollection = 'app_meta';
  static const String _configDocId = 'config';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
  );

  static StudentProfile? _cachedProfile;
  static final NotificationService _notificationService = NotificationService();

  static User? get currentUser {
    try {
      return _authOrNull?.currentUser;
    } catch (_) {
      return null;
    }
  }

  static bool get isLoggedIn {
    final User? user = currentUser;
    return user != null && user.emailVerified;
  }

  static String get currentRole {
    final String? email = currentUser?.email?.trim().toLowerCase();
    if (email == superAdminEmail) {
      return StudentProfile.superAdminRole;
    }
    if (_isSpecialAllowedUserEmail(email)) {
      return StudentProfile.userRole;
    }
    return _cachedProfile?.role ?? StudentProfile.userRole;
  }

  static bool get isSuperAdmin {
    return currentRole == StudentProfile.superAdminRole;
  }

  static bool get isAdmin {
    return isSuperAdmin || currentRole == StudentProfile.adminRole;
  }

  static bool get canModerateContent => isAdmin;

  static bool isAllowedSignInEmail(String email) {
    final String normalizedEmail = email.trim().toLowerCase();
    return StudentProfile.isValidEwuEmail(normalizedEmail) ||
        _isSpecialAllowedUserEmail(normalizedEmail);
  }

  static Future<User?> register(String email, String password) async {
    final String normalizedEmail = email.trim().toLowerCase();
    _validateAllowedEmail(normalizedEmail);

    try {
      final UserCredential credential = await _requireAuth()
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
      await credential.user?.sendEmailVerification();
      await _syncProfileAfterAuth(
        email: normalizedEmail,
        user: credential.user,
        name: credential.user?.displayName,
        photoUrl: credential.user?.photoURL,
      );
      return credential.user;
    } on FirebaseAuthException catch (error) {
      throw Exception(_mapFirebaseError(error.code));
    } catch (error) {
      throw Exception(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<User?> signIn(String email, String password) async {
    final String normalizedEmail = email.trim().toLowerCase();
    _validateAllowedEmail(normalizedEmail);

    try {
      final UserCredential credential = await _requireAuth()
          .signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );

      await _syncProfileAfterAuth(
        email: normalizedEmail,
        user: credential.user,
        name: credential.user?.displayName,
        photoUrl: credential.user?.photoURL,
      );
      return credential.user;
    } on FirebaseAuthException catch (error) {
      throw Exception(_mapFirebaseError(error.code));
    } catch (error) {
      throw Exception(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final String email = googleUser.email.trim().toLowerCase();
      _validateAllowedEmail(email);

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _requireAuth()
          .signInWithCredential(credential);

      await _syncProfileAfterAuth(
        email: email,
        user: userCredential.user,
        name: userCredential.user?.displayName ?? googleUser.displayName,
        photoUrl: userCredential.user?.photoURL ?? googleUser.photoUrl,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (error) {
      throw Exception(_mapFirebaseError(error.code));
    } catch (error) {
      await _googleSignIn.signOut();
      throw Exception(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<void> resendVerificationEmail() async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('Please sign in first so we can resend the email.');
    }
    if (user.emailVerified) {
      return;
    }

    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw Exception(_mapFirebaseError(error.code));
    } catch (error) {
      throw Exception(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<bool> checkEmailVerified() async {
    final FirebaseAuth auth = _requireAuth();
    final User? user = auth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      await user.reload();
      final User? refreshedUser = auth.currentUser;
      if (refreshedUser?.emailVerified == true) {
        await _syncProfileAfterAuth(
          email: refreshedUser?.email?.trim().toLowerCase() ?? '',
          user: refreshedUser,
          name: refreshedUser?.displayName,
          photoUrl: refreshedUser?.photoURL,
        );
        return true;
      }
      return false;
    } on FirebaseAuthException {
      return auth.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveProfile(StudentProfile profile) async {
    final StudentProfile resolvedProfile = await _persistProfile(profile);
    await _cacheProfile(resolvedProfile);
  }

  static Future<StudentProfile?> getProfile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final StudentProfile? cachedProfile =
        _cachedProfile ??
        StudentProfile.decode(prefs.getString(_profileStorageKey));
    if (cachedProfile != null) {
      _cachedProfile = cachedProfile;
    }

    final FirebaseFirestore? firestore = _firestoreOrNull;
    final User? user = currentUser;
    if (firestore == null || user == null) {
      return cachedProfile;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await firestore.collection(_usersCollection).doc(user.uid).get();
      if (userSnapshot.exists) {
        final StudentProfile remoteProfile = _mergeWithCurrentUser(
          StudentProfile.fromJson(userSnapshot.data() ?? <String, dynamic>{}),
          firebaseUser: user,
          fallbackJoinedAt: cachedProfile?.joinedAt,
        );
        final StudentProfile resolvedProfile = await _persistProfile(
          remoteProfile,
          writeFirestore: false,
        );
        await _cacheProfile(resolvedProfile);
        return resolvedProfile;
      }

      final DocumentSnapshot<Map<String, dynamic>> legacySnapshot =
          await firestore
              .collection(_legacyProfilesCollection)
              .doc(user.uid)
              .get();
      if (legacySnapshot.exists) {
        final StudentProfile legacyProfile = _mergeWithCurrentUser(
          StudentProfile.fromJson(legacySnapshot.data() ?? <String, dynamic>{}),
          firebaseUser: user,
          fallbackJoinedAt: cachedProfile?.joinedAt,
        );
        await saveProfile(legacyProfile);
        return _cachedProfile ?? legacyProfile;
      }

      final StudentProfile generatedProfile = _mergeWithCurrentUser(
        StudentProfile.fromEmail(
          email: user.email?.trim().toLowerCase() ?? '',
          name: user.displayName,
          photoUrl: user.photoURL,
          joinedAt: cachedProfile?.joinedAt,
        ),
        firebaseUser: user,
        fallbackJoinedAt: cachedProfile?.joinedAt,
      );
      await _cacheProfileBestEffort(generatedProfile);
      await saveProfile(generatedProfile);
      return _cachedProfile ?? generatedProfile;
    } catch (_) {
      if (cachedProfile != null) {
        return cachedProfile;
      }
      final StudentProfile fallbackProfile = _mergeWithCurrentUser(
        StudentProfile.fromEmail(
          email: user.email?.trim().toLowerCase() ?? '',
          name: user.displayName,
          photoUrl: user.photoURL,
          joinedAt: cachedProfile?.joinedAt,
        ),
        firebaseUser: user,
        fallbackJoinedAt: cachedProfile?.joinedAt,
      );
      await _cacheProfileBestEffort(fallbackProfile);
      return fallbackProfile;
    }
  }

  static Future<void> ensureCurrentUserProfile() async {
    final User? user = currentUser;
    if (user == null) {
      return;
    }

    final StudentProfile profile = _mergeWithCurrentUser(
      _cachedProfile ??
          StudentProfile.fromEmail(
            email: user.email?.trim().toLowerCase() ?? '',
            name: user.displayName,
            photoUrl: user.photoURL,
          ),
      firebaseUser: user,
      fallbackJoinedAt: _cachedProfile?.joinedAt,
    );
    try {
      await saveProfile(profile);
    } catch (_) {
      await _cacheProfileBestEffort(profile);
    }
  }

  static Stream<RoleConfigData> watchRoleConfig() {
    final FirebaseFirestore? firestore = _firestoreOrNull;
    if (firestore == null || currentUser == null) {
      return Stream<RoleConfigData>.value(
        RoleConfigData(
          superAdminEmail: superAdminEmail,
          adminEmails: const <String>[],
        ),
      );
    }

    return firestore
        .collection(_appMetaCollection)
        .doc(_configDocId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          return RoleConfigData.fromJson(
            snapshot.data() ?? <String, dynamic>{},
            fallbackSuperAdminEmail: superAdminEmail,
          );
        });
  }

  static Stream<List<UserDirectoryRecord>> watchUsers() {
    final FirebaseFirestore? firestore = _firestoreOrNull;
    if (firestore == null || currentUser == null) {
      return Stream<List<UserDirectoryRecord>>.value(
        const <UserDirectoryRecord>[],
      );
    }

    return firestore.collection(_usersCollection).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<UserDirectoryRecord> records = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            StudentProfile profile = StudentProfile.fromJson(doc.data());
            if (_isSuperAdminEmail(profile.email)) {
              profile = profile.copyWith(role: StudentProfile.superAdminRole);
            } else if (_isSpecialAllowedUserEmail(profile.email)) {
              profile = profile.copyWith(role: StudentProfile.userRole);
            }
            return UserDirectoryRecord(uid: doc.id, profile: profile);
          })
          .where((UserDirectoryRecord record) {
            return record.profile.email.isNotEmpty;
          })
          .toList();

      records.sort((UserDirectoryRecord a, UserDirectoryRecord b) {
        return a.profile.name.toLowerCase().compareTo(
          b.profile.name.toLowerCase(),
        );
      });
      return records;
    });
  }

  static Future<void> promoteToAdmin({
    required String uid,
    required String email,
  }) async {
    final FirebaseFirestore firestore = _requireFirestore();
    if (!isSuperAdmin) {
      throw Exception('Only the super admin can assign admin roles.');
    }

    final String normalizedEmail = email.trim().toLowerCase();
    if (_isSuperAdminEmail(normalizedEmail)) {
      throw Exception('The super admin role is fixed and cannot be changed.');
    }
    if (_isSpecialAllowedUserEmail(normalizedEmail)) {
      throw Exception(
        'The approved personal email stays a normal user account and cannot be promoted to admin.',
      );
    }

    final RoleConfigData config = await _ensureRoleConfig(firestore);
    final List<String> adminEmails = List<String>.from(config.adminEmails);
    if (!adminEmails.contains(normalizedEmail) &&
        adminEmails.length >= maxAdminCount) {
      throw Exception('You can assign up to $maxAdminCount admins.');
    }

    if (!adminEmails.contains(normalizedEmail)) {
      adminEmails.add(normalizedEmail);
    }

    final RoleConfigData updatedConfig = config.copyWith(
      adminEmails: adminEmails,
    );
    await _writeRoleConfig(firestore, updatedConfig);
    await _writeUserRole(
      firestore,
      uid: uid,
      email: normalizedEmail,
      role: StudentProfile.adminRole,
    );
    await _notificationService.createNotification(
      toUid: uid,
      type: 'admin_promotion',
      title: 'Admin access granted',
      body: 'You can now moderate campus content in EWU Assistant.',
      senderUid: currentUser?.uid ?? '',
      senderName: _cachedProfile?.name ?? 'Super Admin',
    );
  }

  static Future<void> removeAdminRole({
    required String uid,
    required String email,
  }) async {
    final FirebaseFirestore firestore = _requireFirestore();
    if (!isSuperAdmin) {
      throw Exception('Only the super admin can remove admin roles.');
    }

    final String normalizedEmail = email.trim().toLowerCase();
    if (_isSuperAdminEmail(normalizedEmail)) {
      throw Exception('The super admin role cannot be removed.');
    }

    final RoleConfigData config = await _ensureRoleConfig(firestore);
    final List<String> adminEmails = List<String>.from(config.adminEmails)
      ..remove(normalizedEmail);

    final RoleConfigData updatedConfig = config.copyWith(
      adminEmails: adminEmails,
    );
    await _writeRoleConfig(firestore, updatedConfig);
    await _writeUserRole(
      firestore,
      uid: uid,
      email: normalizedEmail,
      role: StudentProfile.userRole,
    );
    await _notificationService.createNotification(
      toUid: uid,
      type: 'admin_update',
      title: 'Admin access removed',
      body:
          'Your admin role was removed. Standard student access remains active.',
      senderUid: currentUser?.uid ?? '',
      senderName: _cachedProfile?.name ?? 'Super Admin',
    );
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore Google session cleanup issues.
    }

    final FirebaseAuth? auth = _authOrNull;
    if (auth != null) {
      await auth.signOut();
    }

    _cachedProfile = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileStorageKey);
  }

  static Future<void> sendPasswordReset(String email) async {
    final String normalizedEmail = email.trim().toLowerCase();
    _validateAllowedEmail(normalizedEmail);

    try {
      await _requireAuth().sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      throw Exception(_mapFirebaseError(error.code));
    } catch (error) {
      throw Exception(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<StudentProfile> _persistProfile(
    StudentProfile profile, {
    bool writeFirestore = true,
  }) async {
    final User? user = currentUser;
    final StudentProfile mergedProfile = _mergeWithCurrentUser(
      profile,
      firebaseUser: user,
      fallbackJoinedAt: _cachedProfile?.joinedAt,
    );

    final FirebaseFirestore? firestore = _firestoreOrNull;
    RoleConfigData? config;
    if (firestore != null) {
      try {
        config = await _ensureRoleConfig(firestore);
      } catch (_) {
        config = null;
      }
    }

    final String resolvedRole = _resolveRole(
      email: mergedProfile.email,
      config: config,
      fallbackRole: mergedProfile.role,
    );
    final StudentProfile resolvedProfile = mergedProfile.copyWith(
      role: resolvedRole,
    );

    if (writeFirestore && firestore != null && user != null) {
      try {
        final Map<String, dynamic> data = resolvedProfile.toJson();
        await firestore
            .collection(_usersCollection)
            .doc(user.uid)
            .set(data, SetOptions(merge: true));

        await firestore
            .collection(_legacyProfilesCollection)
            .doc(user.uid)
            .set(data, SetOptions(merge: true));
      } catch (_) {
        // Keep sign-in and profile loading usable even if Firestore sync fails.
      }
    }

    return resolvedProfile;
  }

  static StudentProfile _mergeWithCurrentUser(
    StudentProfile profile, {
    required User? firebaseUser,
    required DateTime? fallbackJoinedAt,
  }) {
    final String email =
        firebaseUser?.email?.trim().toLowerCase() ??
        profile.email.trim().toLowerCase();
    final String effectiveStudentId = profile.studentId.isNotEmpty
        ? profile.studentId
        : (StudentProfile.extractStudentId(email) ?? '');
    final DateTime joinedAt = _cachedProfile?.email == email
        ? _cachedProfile!.joinedAt
        : fallbackJoinedAt ?? profile.joinedAt;

    return profile.copyWith(
      name: firebaseUser?.displayName?.trim().isNotEmpty == true
          ? firebaseUser!.displayName!.trim()
          : profile.name,
      email: email,
      studentId: effectiveStudentId,
      department: StudentProfile.detectDepartment(effectiveStudentId),
      batchYear: StudentProfile.detectBatchYear(effectiveStudentId),
      photoUrl: firebaseUser?.photoURL ?? profile.photoUrl,
      joinedAt: joinedAt,
    );
  }

  static Future<void> _cacheProfile(StudentProfile profile) async {
    _cachedProfile = profile;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileStorageKey, StudentProfile.encode(profile));
  }

  static Future<void> _syncProfileAfterAuth({
    required String email,
    required User? user,
    String? name,
    String? photoUrl,
  }) async {
    final StudentProfile profile = StudentProfile.fromEmail(
      email: email,
      name: name,
      photoUrl: photoUrl,
      joinedAt: _cachedProfile?.joinedAt,
    );

    try {
      await saveProfile(profile);
    } catch (_) {
      await _cacheProfileBestEffort(
        _mergeWithCurrentUser(
          profile,
          firebaseUser: user,
          fallbackJoinedAt: _cachedProfile?.joinedAt,
        ),
      );
    }
  }

  static Future<void> _cacheProfileBestEffort(StudentProfile profile) async {
    try {
      await _cacheProfile(profile);
    } catch (_) {
      _cachedProfile = profile;
    }
  }

  static Future<RoleConfigData> _ensureRoleConfig(
    FirebaseFirestore firestore,
  ) async {
    final DocumentReference<Map<String, dynamic>> ref = firestore
        .collection(_appMetaCollection)
        .doc(_configDocId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
    final RoleConfigData config = RoleConfigData.fromJson(
      snapshot.data() ?? <String, dynamic>{},
      fallbackSuperAdminEmail: superAdminEmail,
    );

    final Map<String, dynamic> normalizedData = config.toJson();
    if (!snapshot.exists) {
      await ref.set(normalizedData, SetOptions(merge: true));
    } else {
      final Map<String, dynamic> currentData =
          snapshot.data() ?? <String, dynamic>{};
      final List<String> currentAdminEmails = List<String>.from(
        currentData['adminEmails'] as List? ?? const <String>[],
      ).map((String value) => value.trim().toLowerCase()).toList();
      final String currentSuperAdmin =
          currentData['superAdminEmail']?.toString().trim().toLowerCase() ?? '';
      if (currentSuperAdmin != config.superAdminEmail ||
          currentAdminEmails.length != config.adminEmails.length ||
          !_sameEmails(currentAdminEmails, config.adminEmails)) {
        await ref.set(normalizedData, SetOptions(merge: true));
      }
    }

    return config;
  }

  static Future<void> _writeRoleConfig(
    FirebaseFirestore firestore,
    RoleConfigData config,
  ) async {
    await firestore
        .collection(_appMetaCollection)
        .doc(_configDocId)
        .set(config.toJson(), SetOptions(merge: true));
  }

  static Future<void> _writeUserRole(
    FirebaseFirestore firestore, {
    required String uid,
    required String email,
    required String role,
  }) async {
    final String resolvedRole = _resolveRole(
      email: email,
      config: RoleConfigData(
        superAdminEmail: superAdminEmail,
        adminEmails: role == StudentProfile.adminRole
            ? <String>[email]
            : const <String>[],
      ),
      fallbackRole: role,
    );

    await firestore.collection(_usersCollection).doc(uid).set(<String, dynamic>{
      'role': resolvedRole,
    }, SetOptions(merge: true));
    await firestore.collection(_legacyProfilesCollection).doc(uid).set(
      <String, dynamic>{'role': resolvedRole},
      SetOptions(merge: true),
    );

    if (currentUser?.uid == uid && _cachedProfile != null) {
      await _cacheProfile(_cachedProfile!.copyWith(role: resolvedRole));
    }
  }

  static String _resolveRole({
    required String email,
    RoleConfigData? config,
    required String fallbackRole,
  }) {
    final String normalizedEmail = email.trim().toLowerCase();
    if (_isSuperAdminEmail(normalizedEmail)) {
      return StudentProfile.superAdminRole;
    }
    if (_isSpecialAllowedUserEmail(normalizedEmail)) {
      return StudentProfile.userRole;
    }
    if (config != null && config.isAdminEmail(normalizedEmail)) {
      return StudentProfile.adminRole;
    }
    return StudentProfile.normalizeRole(fallbackRole);
  }

  static bool _sameEmails(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    final List<String> sortedA = List<String>.from(a)..sort();
    final List<String> sortedB = List<String>.from(b)..sort();
    for (int index = 0; index < sortedA.length; index++) {
      if (sortedA[index] != sortedB[index]) {
        return false;
      }
    }
    return true;
  }

  static bool _isSuperAdminEmail(String email) {
    return email.trim().toLowerCase() == superAdminEmail;
  }

  static bool _isSpecialAllowedUserEmail(String? email) {
    return email?.trim().toLowerCase() == specialAllowedUserEmail;
  }

  static FirebaseAuth _requireAuth() {
    final FirebaseAuth? auth = _authOrNull;
    if (auth == null) {
      throw Exception(
        'Firebase authentication is unavailable right now. Please restart the app and try again.',
      );
    }
    return auth;
  }

  static FirebaseFirestore _requireFirestore() {
    final FirebaseFirestore? firestore = _firestoreOrNull;
    if (firestore == null) {
      throw Exception(
        'Firestore is unavailable right now. Please restart the app and try again.',
      );
    }
    return firestore;
  }

  static FirebaseAuth? get _authOrNull {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseAuth.instance;
  }

  static FirebaseFirestore? get _firestoreOrNull {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseFirestore.instance;
  }

  static void _validateAllowedEmail(String email) {
    if (!isAllowedSignInEmail(email)) {
      throw Exception(
        'Please use your EWU student email address or the approved access email for this app.',
      );
    }
  }

  static String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'user-not-found':
        return 'No account was found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password did not match.';
      case 'too-many-requests':
        return 'Too many attempts were made. Please wait a little and try again.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'credential-already-in-use':
        return 'This sign-in credential is already linked to another account.';
      case 'invalid-action-code':
        return 'This verification or reset link is no longer valid.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase yet.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
