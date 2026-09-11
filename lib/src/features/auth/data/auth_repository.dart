import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../database/app_database.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final bool isGuest;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.isGuest,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isGuest': isGuest,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isGuest: map['isGuest'] ?? false,
    );
  }

  factory UserProfile.fromFirebaseUser(fb_auth.User user) {
    return UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName?.isNotEmpty == true
          ? user.displayName!
          : (user.email ?? 'User'),
      photoUrl: user.photoURL ?? '',
      isGuest: false,
    );
  }
}

/// Thrown by [AuthNotifier.signInWithGoogle] when the user dismisses the
/// account picker rather than a real sign-in failure, so callers can ignore
/// it instead of surfacing an error.
class GoogleSignInCancelled implements Exception {}

const _guestProfileKey = 'guest_profile';

class AuthNotifier extends StateNotifier<UserProfile?> {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  StreamSubscription<fb_auth.User?>? _authSub;
  bool _googleSignInReady = false;

  AuthNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    // Fire-and-forget: initialize() must be called before authenticate(),
    // but a slow/failed init shouldn't block reading the existing auth
    // state (e.g. a returning signed-in user) on app start.
    unawaited(_ensureGoogleSignInReady());

    // Firebase's auth state is the source of truth for real accounts. Guest
    // mode is a purely local, app-invented concept Firebase has no notion
    // of, so it's only consulted when there's no real Firebase session.
    _authSub = fb_auth.FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (user != null) {
        state = UserProfile.fromFirebaseUser(user);
      } else {
        await _loadGuestState();
      }
    });
  }

  Future<void> _ensureGoogleSignInReady() async {
    if (_googleSignInReady) return;
    // serverClientId must be the Firebase project's *Web* OAuth client
    // (client_type 3 in google-services.json), not the Android one -- on
    // Android, google_sign_in only returns a non-null idToken from
    // authenticate() when this is set. Without it, authenticate() still
    // succeeds (the account picker works fine) but idToken comes back
    // null, so the later signInWithCredential() call fails, surfacing as
    // "Google Sign-In failed" with no more specific error.
    await _googleSignIn.initialize(
      serverClientId:
          '836907422627-m414hgv46747es6t0m6jg6ssdp5c965u.apps.googleusercontent.com',
    );
    _googleSignInReady = true;
  }

  Future<void> _loadGuestState() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_guestProfileKey);
    state = userJson != null ? UserProfile.fromMap(jsonDecode(userJson)) : null;
  }

  Future<void> signInAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final guest = UserProfile(
      uid: 'guest_user_id',
      email: 'guest@finflow.local',
      displayName: 'Guest User',
      photoUrl: '',
      isGuest: true,
    );
    await prefs.setString(_guestProfileKey, jsonEncode(guest.toMap()));
    state = guest;
  }

  /// Throws [GoogleSignInCancelled] if the user dismisses the account
  /// picker; any other thrown exception is a genuine sign-in failure.
  Future<UserProfile> signInWithGoogle() async {
    await _ensureGoogleSignInReady();

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw GoogleSignInCancelled();
      }
      rethrow;
    }

    final idToken = googleUser.authentication.idToken;
    final credential = fb_auth.GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await fb_auth.FirebaseAuth.instance
        .signInWithCredential(credential);

    // authStateChanges() will also update `state` asynchronously, but
    // returning the profile directly lets the caller proceed immediately
    // rather than waiting on the stream to fire.
    return UserProfile.fromFirebaseUser(userCredential.user!);
  }

  Future<UserProfile> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await fb_auth.FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final user = credential.user!;
    if (displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
      await user.reload();
    }
    return UserProfile.fromFirebaseUser(
      fb_auth.FirebaseAuth.instance.currentUser ?? user,
    );
  }

  Future<UserProfile> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await fb_auth.FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    return UserProfile.fromFirebaseUser(credential.user!);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await fb_auth.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestProfileKey);

    if (fb_auth.FirebaseAuth.instance.currentUser != null) {
      if (_googleSignInReady) {
        await _googleSignIn.signOut();
      }
      await fb_auth.FirebaseAuth.instance.signOut();
    }

    // Local SQLite is a per-signed-in-account offline cache (every
    // repository write-throughs to it), not just guest storage. Without
    // clearing it here, a second account signing in on the same device
    // could fall back to reading the first account's cached data if its own
    // Firestore read ever failed -- local has no uid-scoping to prevent
    // that, so wiping it on sign-out is the only thing that does.
    await AppDatabase.instance.clearAllData();

    state = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserProfile?>((ref) {
  return AuthNotifier();
});
