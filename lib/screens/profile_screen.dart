import 'package:flutter/material.dart';
import 'package:my_stories/models/user_profile.dart';
import 'package:my_stories/repositories/auth_repository.dart';
import 'package:my_stories/screens/auth_screen.dart';
import 'package:my_stories/services/story_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.authRepository,
    required this.storyRepository,
  });

  final AuthRepository authRepository;
  final StoryRepository storyRepository;

  @override
  Widget build(BuildContext context) {
    final user =
        authRepository.currentUser ??
        UserProfile(
          id: 'local_user',
          email: 'reader@example.com',
          username: 'reader',
          displayName: 'Reader One',
          bio: 'Reader and storyteller.',
          followerCount: 0,
          followingCount: 0,
          storyCount: 0,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () async {
              await authRepository.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(
                      authRepository: authRepository,
                      storyRepository: storyRepository,
                    ),
                  ),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFF4F46E5),
                    child: Text(
                      user.displayName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${user.username}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF77748A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              user.bio,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF464358)),
            ),
            const SizedBox(height: 26),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Followers', value: '${user.followerCount}'),
                _Stat(label: 'Following', value: '${user.followingCount}'),
                _Stat(label: 'Stories', value: '${user.storyCount}'),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded),
              label: const Text('Publish a story'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF77748A)),
        ),
      ],
    );
  }
}
