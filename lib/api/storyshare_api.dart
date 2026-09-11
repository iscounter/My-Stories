import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_stories/core/config/app_config.dart';

class StoryShareApi {
  StoryShareApi({String? baseUrl, String? authToken})
      : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl + AppConfig.apiPrefix,
        _authToken = authToken;

  final String _baseUrl;
  final String? _authToken;

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _authToken ?? '';
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<ApiResponse<T>> _request<T>(
    String path,
    T Function(http.Response response) parser, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final normalizedPath = path.startsWith('/webstore/')
        ? path.substring('/webstore'.length)
        : path;
    final uri = Uri.parse(
      '$_baseUrl$normalizedPath',
    ).replace(queryParameters: query ?? const {});

    http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(
          uri,
          headers: _headers,
          body: jsonEncode(body ?? {}),
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: _headers,
          body: jsonEncode(body ?? {}),
        );
        break;
      case 'DELETE':
        response = await http.delete(
          uri,
          headers: _headers,
          body: jsonEncode(body ?? {}),
        );
        break;
      case 'GET':
      default:
        response = await http.get(uri, headers: _headers);
        break;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse<T>(
        statusCode: response.statusCode,
        data: parser(response),
      );
    }

    final payload =
        jsonDecode(response.body.isNotEmpty ? response.body : '{}')
            as Map<String, dynamic>;
    throw ApiException(
      statusCode: response.statusCode,
      message: payload['error'] ?? 'Request failed.',
    );
  }

  Future<AuthResult> register({
    required String email,
    required String username,
    required String displayName,
    required String password,
  }) async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/auth/register',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'POST',
      body: {
        'email': email,
        'username': username,
        'displayName': displayName,
        'password': password,
      },
    );

    return AuthResult.fromJson(result.data);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/auth/login',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'POST',
      body: {'email': email, 'password': password},
    );

    return AuthResult.fromJson(result.data);
  }

  Future<void> logout() async {
    await _request<Map<String, dynamic>>(
      '/webstore/auth/logout',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'POST',
    );
  }

  Future<UserProfile> me() async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/auth/me',
      (response) =>
          (jsonDecode(response.body) as Map<String, dynamic>)['user']
              as Map<String, dynamic>,
      method: 'GET',
    );
    return UserProfile.fromJson(result.data);
  }

  Future<List<StoryApiModel>> fetchStories({
    String? category,
    String? authorId,
    int limit = 20,
  }) async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/stories',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'GET',
      query: {
        if (category != null) 'category': category,
        if (authorId != null) 'authorId': authorId,
        'limit': limit.toString(),
      },
    );

    final items = (result.data['stories'] as List?) ?? const [];
    return items
        .map((e) => StoryApiModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StoryApiModel> createStory({
    required String title,
    required String body,
    required String category,
    List<String> tags = const [],
    bool isAnonymous = false,
    String? coverImageUrl,
  }) async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/stories',
      (response) =>
          (jsonDecode(response.body) as Map<String, dynamic>)['story']
              as Map<String, dynamic>,
      method: 'POST',
      body: {
        'title': title,
        'body': body,
        'category': category,
        'tags': tags,
        'isAnonymous': isAnonymous,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      },
    );
    return StoryApiModel.fromJson(result.data);
  }

  Future<StoryApiModel> updateStory(
    String storyId, {
    String? title,
    String? body,
    String? category,
    List<String>? tags,
    String? coverImageUrl,
  }) async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/stories/$storyId',
      (response) =>
          (jsonDecode(response.body) as Map<String, dynamic>)['story']
              as Map<String, dynamic>,
      method: 'PUT',
      body: {
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (category != null) 'category': category,
        if (tags != null) 'tags': tags,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      },
    );
    return StoryApiModel.fromJson(result.data);
  }

  Future<void> deleteStory(String storyId) async {
    await _request<Map<String, dynamic>>(
      '/webstore/stories/$storyId',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'DELETE',
    );
  }

  Future<StoryLikeState> toggleLike(String storyId) async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/stories/$storyId/like',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'POST',
    );
    return StoryLikeState.fromJson(result.data);
  }

  Future<List<CommentApiModel>> fetchComments(String storyId) async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/stories/$storyId/comments',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'GET',
    );

    final items = (result.data['comments'] as List?) ?? const [];
    return items
        .map(
          (e) => CommentApiModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<CommentApiModel> addComment(
    String storyId, {
    required String text,
    String? parentId,
  }) async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/stories/$storyId/comments',
      (response) =>
          (jsonDecode(response.body) as Map<String, dynamic>)['comment']
              as Map<String, dynamic>,
      method: 'POST',
      body: {'text': text, if (parentId != null) 'parentId': parentId},
    );
    return CommentApiModel.fromJson(result.data);
  }

  Future<List<BookmarkApiModel>> fetchBookmarks() async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/bookmarks',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'GET',
    );
    final items = (result.data['bookmarks'] as List?) ?? const [];
    return items
        .map(
          (e) => BookmarkApiModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> saveBookmark(String storyId) async {
    await _request<Map<String, dynamic>>(
      '/webstore/bookmarks',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'POST',
      body: {'storyId': storyId},
    );
  }

  Future<void> followUser(String userId) async {
    await _request<Map<String, dynamic>>(
      '/webstore/follow',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'POST',
      body: {'userId': userId},
    );
  }

  Future<void> unfollowUser(String userId) async {
    await _request<Map<String, dynamic>>(
      '/webstore/follow',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'DELETE',
      body: {'userId': userId},
    );
  }

  Future<List<NotificationApiModel>> fetchNotifications() async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/notifications',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'GET',
    );
    final items = (result.data['notifications'] as List?) ?? const [];
    return items
        .map(
          (e) => NotificationApiModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _request<Map<String, dynamic>>(
      '/webstore/notifications',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'POST',
      body: {'notificationId': notificationId},
    );
  }

  Future<Map<String, dynamic>> search(String query) async {
    final result = await _request<Map<String, dynamic>>(
      '/webstore/search',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'GET',
      query: {'q': query},
    );
    return result.data;
  }

  Future<void> reportStory({
    required String targetType,
    required String targetId,
    required String reason,
    String note = '',
  }) async {
    await _request<Map<String, dynamic>>(
      '/webstore/reports',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      method: 'POST',
      body: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'note': note,
      },
    );
  }
}

class ApiResponse<T> {
  const ApiResponse({required this.statusCode, required this.data});

  final int statusCode;
  final T data;
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthResult {
  AuthResult({required this.user, this.token});

  final UserProfile user;
  final String? token;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      user: UserProfile.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      token: json['user']?['token'] as String?,
    );
  }
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.bio,
    this.photoUrl,
    required this.followerCount,
    required this.followingCount,
    required this.storyCount,
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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
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

class StoryApiModel {
  StoryApiModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    required this.isAnonymous,
    required this.title,
    required this.body,
    required this.paragraphs,
    required this.category,
    required this.tags,
    this.coverImageUrl,
    required this.readingMinutes,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final bool isAnonymous;
  final String title;
  final String body;
  final List<String> paragraphs;
  final String category;
  final List<String> tags;
  final String? coverImageUrl;
  final int readingMinutes;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StoryApiModel.fromJson(Map<String, dynamic> json) {
    final rawParagraphs = json['paragraphs'];
    final paragraphs = rawParagraphs is String
      ? ((jsonDecode(rawParagraphs) as List?) ?? const [])
          .whereType<String>()
          .toList()
      : rawParagraphs is List
      ? rawParagraphs.whereType<String>().toList()
      : <String>[];

    final rawTags = json['tags'];
    final tags = rawTags is String
      ? ((jsonDecode(rawTags) as List?) ?? const [])
          .whereType<String>()
          .toList()
      : rawTags is List
      ? rawTags.whereType<String>().toList()
      : <String>[];

    return StoryApiModel(
      id: json['id'] as String? ?? '',
      authorId:
          json['author_id'] as String? ?? json['authorId'] as String? ?? '',
      authorName:
          json['author_name'] as String? ??
          json['authorName'] as String? ??
          'Anonymous',
      authorPhoto:
          json['author_photo'] as String? ?? json['authorPhoto'] as String?,
      isAnonymous: json['is_anonymous'] == 1 || json['isAnonymous'] == true,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      paragraphs: paragraphs,
      category: json['category'] as String? ?? 'General',
      tags: tags,
      coverImageUrl:
          json['cover_image_url'] as String? ??
          json['coverImageUrl'] as String?,
      readingMinutes:
          (json['reading_minutes'] as num?)?.toInt() ??
          (json['readingMinutes'] as num?)?.toInt() ??
          1,
      likeCount:
          (json['like_count'] as num?)?.toInt() ??
          (json['likeCount'] as num?)?.toInt() ??
          0,
      commentCount:
          (json['comment_count'] as num?)?.toInt() ??
          (json['commentCount'] as num?)?.toInt() ??
          0,
      viewCount:
          (json['view_count'] as num?)?.toInt() ??
          (json['viewCount'] as num?)?.toInt() ??
          0,
      isPublished: json['is_published'] == 1 || json['isPublished'] == true,
      createdAt:
          DateTime.tryParse(
            json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(
            json['updated_at'] as String? ?? json['updatedAt'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class StoryLikeState {
  StoryLikeState({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;

  factory StoryLikeState.fromJson(Map<String, dynamic> json) {
    return StoryLikeState(
      liked: json['liked'] == true,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CommentApiModel {
  CommentApiModel({
    required this.id,
    required this.storyId,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    required this.text,
    this.parentId,
    required this.likeCount,
    required this.createdAt,
    required this.isDeleted,
  });

  final String id;
  final String storyId;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String text;
  final String? parentId;
  final int likeCount;
  final DateTime createdAt;
  final bool isDeleted;

  factory CommentApiModel.fromJson(Map<String, dynamic> json) {
    return CommentApiModel(
      id: json['id'] as String? ?? '',
      storyId: json['story_id'] as String? ?? json['storyId'] as String? ?? '',
      authorId:
          json['author_id'] as String? ?? json['authorId'] as String? ?? '',
      authorName:
          json['author_name'] as String? ??
          json['authorName'] as String? ??
          'Anonymous',
      authorPhoto:
          json['author_photo'] as String? ?? json['authorPhoto'] as String?,
      text: json['text'] as String? ?? '',
      parentId: json['parent_id'] as String? ?? json['parentId'] as String?,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(
            json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      isDeleted: json['is_deleted'] == 1 || json['isDeleted'] == true,
    );
  }
}

class BookmarkApiModel {
  BookmarkApiModel({
    required this.userId,
    required this.storyId,
    required this.savedAt,
    this.title,
  });

  final String userId;
  final String storyId;
  final DateTime savedAt;
  final String? title;

  factory BookmarkApiModel.fromJson(Map<String, dynamic> json) {
    return BookmarkApiModel(
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      storyId: json['story_id'] as String? ?? json['storyId'] as String? ?? '',
      savedAt:
          DateTime.tryParse(
            json['saved_at'] as String? ?? json['savedAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      title: json['title'] as String?,
    );
  }
}

class NotificationApiModel {
  NotificationApiModel({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.actorName,
    required this.type,
    this.storyId,
    this.commentId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String recipientId;
  final String actorId;
  final String actorName;
  final String type;
  final String? storyId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationApiModel.fromJson(Map<String, dynamic> json) {
    return NotificationApiModel(
      id: json['id'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? '',
      actorId: json['actor_id'] as String? ?? '',
      actorName: json['actor_name'] as String? ?? '',
      type: json['type'] as String? ?? 'like',
      storyId: json['story_id'] as String? ?? json['storyId'] as String?,
      commentId: json['comment_id'] as String? ?? json['commentId'] as String?,
      isRead: json['is_read'] == 1 || json['isRead'] == true,
      createdAt:
          DateTime.tryParse(
            json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }
}
