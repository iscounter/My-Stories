import 'package:flutter/material.dart';
import 'package:my_stories/screens/home_screen.dart';
import 'package:my_stories/services/story_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await StoryRepository.initialize();
  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.repository});

  final StoryRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Stories',
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
      home: HomeScreen(repository: repository),
    );
  }
}
