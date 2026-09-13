import 'package:flutter_test/flutter_test.dart';
import 'package:my_stories/models/story.dart';
import 'package:my_stories/models/user_profile.dart';
import 'package:my_stories/repositories/auth_repository.dart';
import 'package:my_stories/services/story_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auth repository stores a signed in user', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = await AuthRepository.initialize();
    final user = UserProfile(
      id: 'u_123',
      email: 'reader@example.com',
      username: 'reader',
      displayName: 'Reader One',
      bio: 'Loves thoughtful stories.',
      photoUrl: null,
      followerCount: 0,
      followingCount: 0,
      storyCount: 0,
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
    );

    await repository.signIn(user);
    expect(repository.currentUser?.username, 'reader');
    expect(repository.isSignedIn, isTrue);
  });

  test('story repository searches stories by title and tags', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = await StoryRepository.initialize();
    final story = Story(
      id: 'searchable-story',
      title: 'Starlight Memory',
      author: 'Ari',
      category: 'Fantasy',
      excerpt: 'A memory in the night sky.',
      content: 'A memory in the night sky with enough story text to be valid.',
      paragraphs: const [
        'A memory in the night sky with enough story text to be valid.',
      ],
      readingMinutes: 2,
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
      tags: const ['hope', 'night'],
    );

    await repository.upsertStory(story);
    final results = await repository.searchStories('starlight');

    expect(results, isNotEmpty);
    expect(results.first.id, 'searchable-story');
  });
}
