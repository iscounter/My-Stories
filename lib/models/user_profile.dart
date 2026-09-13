import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.bio,
    this.photoUrl,
    this.followerCount = 0,
    this.followingCount = 0,
    this.storyCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String username;
  final String displayName;
  final String bio;
  final String? photoUrl;
  final int followerCount;
  final int followingCount;
  final int storyCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'displayName': displayName,
    'bio': bio,
    'photoUrl': photoUrl,
    'followerCount': followerCount,
    'followingCount': followingCount,
    'storyCount': storyCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Reader',
      bio: json['bio'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      storyCount: (json['storyCount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
