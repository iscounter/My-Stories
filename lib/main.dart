import 'package:flutter/material.dart';
import 'package:my_stories/repositories/auth_repository.dart';
import 'package:my_stories/screens/auth_screen.dart';
import 'package:my_stories/screens/home_screen.dart';
import 'package:my_stories/screens/profile_screen.dart';
import 'package:my_stories/services/story_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authRepository = await AuthRepository.initialize();
  final storyRepository = await StoryRepository.initialize();
  runApp(StoryShareApp(
    authRepository: authRepository,
    storyRepository: storyRepository,
  ));
}

class StoryShareApp extends StatelessWidget {
  const StoryShareApp({
    super.key,
    required this.authRepository,
    required this.storyRepository,
  });

  final AuthRepository authRepository;
  final StoryRepository storyRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StoryShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F5FF),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
      home: authRepository.isSignedIn
          ? StoryShareRoot(
              authRepository: authRepository,
              storyRepository: storyRepository,
            )
          : AuthScreen(
              authRepository: authRepository,
              storyRepository: storyRepository,
            ),
    );
  }
}

class StoryShareRoot extends StatefulWidget {
  const StoryShareRoot({
    super.key,
    required this.authRepository,
    required this.storyRepository,
  });

  final AuthRepository authRepository;
  final StoryRepository storyRepository;

  @override
  State<StoryShareRoot> createState() => _StoryShareRootState();
}

class _StoryShareRootState extends State<StoryShareRoot> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(repository: widget.storyRepository),
      ProfileScreen(
        authRepository: widget.authRepository,
        storyRepository: widget.storyRepository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
