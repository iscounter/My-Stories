import 'dart:convert';

import 'package:my_stories/models/story.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoryRepository {
  StoryRepository(this._preferences);

  static const String _storageKey = 'my_stories.library.v1';
  final SharedPreferences _preferences;

  static Future<StoryRepository> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    return StoryRepository(preferences);
  }

  Future<List<Story>> loadStories() async {
    final encoded = _preferences.getString(_storageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return StorySeed.all();
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return StorySeed.all();

      final stories =
          decoded.whereType<Map<String, dynamic>>().map(Story.fromJson).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return stories;
    } on FormatException {
      return StorySeed.all();
    }
  }

  Future<List<Story>> saveStories(List<Story> stories) async {
    final orderedStories = [...stories]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final encoded = jsonEncode(
      orderedStories.map((story) => story.toJson()).toList(),
    );
    await _preferences.setString(_storageKey, encoded);
    return orderedStories;
  }

  Future<Story> upsertStory(Story story) async {
    final updated = story.copyWith(updatedAt: DateTime.now());
    final stories = await loadStories();
    final index = stories.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      stories.add(updated);
    } else {
      stories[index] = updated;
    }
    await saveStories(stories);
    return updated;
  }

  Future<List<Story>> deleteStory(String storyId) async {
    final stories = await loadStories();
    final filtered = stories.where((story) => story.id != storyId).toList();
    await saveStories(filtered);
    return filtered;
  }

  Future<Story> toggleFavorite(Story story) async {
    final updated = story.copyWith(isFavorite: !story.isFavorite);
    final stories = await loadStories();
    final index = stories.indexWhere((item) => item.id == story.id);
    if (index != -1) stories[index] = updated;
    await saveStories(stories);
    return updated;
  }

  Future<Story> updateProgress(Story story, int progressPercent) async {
    final progress = progressPercent.clamp(0, 100);
    final updated = story.copyWith(progressPercent: progress);
    final stories = await loadStories();
    final index = stories.indexWhere((item) => item.id == story.id);
    if (index != -1) stories[index] = updated;
    await saveStories(stories);
    return updated;
  }
}
