import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
}

class AuthNotifier extends StateNotifier<UserProfile?> {
  AuthNotifier() : super(null) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_profile');
    if (userJson != null) {
      state = UserProfile.fromMap(jsonDecode(userJson));
    }
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
    await prefs.setString('user_profile', jsonEncode(guest.toMap()));
    state = guest;
  }

  Future<void> signInWithGoogle({
    required String uid,
    required String email,
    required String displayName,
    required String photoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final user = UserProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      isGuest: false,
    );
    await prefs.setString('user_profile', jsonEncode(user.toMap()));
    state = user;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile');
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserProfile?>((ref) {
  return AuthNotifier();
});
