import 'package:flutter_test/flutter_test.dart';
import 'package:my_stories/models/story.dart';
import 'package:my_stories/services/story_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Story serialization preserves library data', () {
    final story = StorySeed.all().first;
    final decoded = Story.fromJson(story.toJson());

    expect(decoded.id, story.id);
    expect(decoded.title, story.title);
    expect(decoded.paragraphs, story.paragraphs);
    expect(decoded.progressPercent, 0);
  });

  test('Story copyWith updates progress and favorite state', () {
    final story = StorySeed.all().first;
    final updated = story.copyWith(progressPercent: 75, isFavorite: true);

    expect(updated.progressPercent, 75);
    expect(updated.isFavorite, isTrue);
    expect(story.progressPercent, 0);
    expect(story.isFavorite, isFalse);
  });

  test('Repository persists and reloads custom stories', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = await StoryRepository.initialize();
    final now = DateTime(2026, 9, 10);
    final story = Story(
      id: 'custom-story',
      title: 'A New Beginning',
      author: 'Reader',
      category: 'General',
      excerpt: 'A short test story.',
      content:
          'A short test story with enough words to represent a complete tale.',
      paragraphs: const [
        'A short test story with enough words to represent a complete tale.',
      ],
      readingMinutes: 1,
      createdAt: now,
      updatedAt: now,
    );

    await repository.upsertStory(story);
    final loaded = await repository.loadStories();

    expect(loaded, hasLength(StorySeed.all().length + 1));
    final loadedStory = loaded.firstWhere((item) => item.id == story.id);
    expect(loadedStory.title, story.title);
    expect(loadedStory.isFavorite, isFalse);
  });
}
