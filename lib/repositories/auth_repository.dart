import 'dart:convert';

import 'package:my_stories/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  AuthRepository(this._preferences);

  static const _key = 'storyshare.auth.user.v1';
  final SharedPreferences _preferences;

  static Future<AuthRepository> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    return AuthRepository(preferences);
  }

  UserProfile? get currentUser {
    final jsonString = _preferences.getString(_key);
    if (jsonString == null || jsonString.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return UserProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => currentUser != null;

  Future<void> signIn(UserProfile user) async {
    await _preferences.setString(_key, jsonEncode(user.toJson()));
  }

  Future<void> signOut() async {
    await _preferences.remove(_key);
  }
}
