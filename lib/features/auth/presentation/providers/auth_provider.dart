import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/user_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/local/guest_data_sync.dart';

// ── Guest Session (local, no Firebase needed) ─────────────────────────────────
class GuestSessionNotifier extends StateNotifier<bool> {
  GuestSessionNotifier() : super(false) {
    _load();
  }

  static const _key = 'local_guest_session';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    if (mounted) state = value;
  }
}

final guestSessionProvider =
    StateNotifierProvider<GuestSessionNotifier, bool>(
  (ref) => GuestSessionNotifier(),
);

// ── Guest Display Name ────────────────────────────────────────────────────────
class GuestNameNotifier extends StateNotifier<String> {
  GuestNameNotifier() : super('Guest') {
    _load();
  }

  static const _key = 'guest_display_name';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) state = prefs.getString(_key) ?? 'Guest';
  }

  Future<void> setName(String name) async {
    final newName = name.trim().isEmpty ? 'Guest' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, newName);
    if (mounted) state = newName;
  }
}

final guestNameProvider = StateNotifierProvider<GuestNameNotifier, String>(
  (ref) => GuestNameNotifier(),
);

// ── Auth State Stream ─────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ── Current UserModel ─────────────────────────────────────────────────────────
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  // Local guest session — no Firebase required
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final guestName = ref.watch(guestNameProvider);
    return UserModel.guest(name: guestName);
  }

  final firebaseUser = ref.watch(authStateProvider).valueOrNull;
  if (firebaseUser == null) return null;
  // Legacy: anonymous Firebase user
  if (firebaseUser.isAnonymous) return UserModel.guest();
  try {
    final doc = await FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(firebaseUser.uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  } on FirebaseException {
    return null;
  }
});

// ── Auth Notifier ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier(this._guestSession) : super(const AsyncValue.data(null));

  final GuestSessionNotifier _guestSession;
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  final _firestore = FirebaseFirestore.instance;

  // Google Sign-In
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final googleAuth = await googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Link anonymous account if currently signed in as guest, else sign in fresh
      final currentUser = _auth.currentUser;
      User user;
      if (currentUser != null && currentUser.isAnonymous) {
        final result = await currentUser.linkWithCredential(credential);
        user = result.user!;
      } else {
        final result = await _auth.signInWithCredential(credential);
        user = result.user!;
      }

      // Migrate any locally stored guest data to Firestore
      await GuestDataSync.instance.syncToFirestore(user.uid);

      // Clear local guest flag now that the user is properly signed in
      await _guestSession.set(false);

      // Create or fetch Firestore user profile
      final userModel = await _createOrFetchUser(user);
      state = AsyncValue.data(userModel);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Guest Mode — purely local, no Firebase required
  Future<void> continueAsGuest() async {
    state = const AsyncValue.loading();
    await _guestSession.set(true);
    state = AsyncValue.data(UserModel.guest());
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _guestSession.set(false);
    state = const AsyncValue.data(null);
  }

  Future<UserModel> _createOrFetchUser(User firebaseUser) async {
    final docRef = _firestore
        .collection(AppConstants.colUsers)
        .doc(firebaseUser.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }

    // New user — create Firestore record
    final newUser = UserModel(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'User',
      email: firebaseUser.email ?? '',
      photoUrl: firebaseUser.photoURL,
      createdAt: DateTime.now(),
    );
    await docRef.set(newUser.toFirestore());
    return newUser;
  }

  Future<void> updateUserProfile(UserModel updated) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .update(updated.toFirestore());
    state = AsyncValue.data(updated);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
  (ref) => AuthNotifier(ref.read(guestSessionProvider.notifier)),
);
