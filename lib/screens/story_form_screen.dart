import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_stories/models/story.dart';
import 'package:my_stories/services/story_repository.dart';

class StoryFormScreen extends StatefulWidget {
  const StoryFormScreen({super.key, required this.repository, this.story});

  final StoryRepository repository;
  final Story? story;

  @override
  State<StoryFormScreen> createState() => _StoryFormScreenState();
}

class _StoryFormScreenState extends State<StoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _excerptController = TextEditingController();
  final _contentController = TextEditingController();
  final _minutesController = TextEditingController();

  String _category = 'General';
  bool _isSaving = false;

  static const _categories = [
    'General',
    'Science Fiction',
    'Adventure',
    'Mystery',
    'Fantasy',
    'Romance',
  ];

  @override
  void initState() {
    super.initState();
    final story = widget.story;
    if (story != null) {
      _titleController.text = story.title;
      _authorController.text = story.author;
      _category = story.category;
      _excerptController.text = story.excerpt;
      _contentController.text = story.content;
      _minutesController.text = story.readingMinutes.toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _excerptController.dispose();
    _contentController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final content = _contentController.text.trim();
    final paragraphs = content
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
    final now = DateTime.now();
    final story = widget.story;

    final updated =
        (story ??
                Story(
                  id: '${now.millisecondsSinceEpoch}-${Random().nextInt(100000)}',
                  title: _titleController.text.trim(),
                  author: _authorController.text.trim(),
                  category: _category,
                  excerpt: _excerptController.text.trim(),
                  content: content,
                  paragraphs: paragraphs,
                  readingMinutes: int.parse(_minutesController.text),
                  createdAt: now,
                  updatedAt: now,
                  coverColors: _coverHexColors(_category),
                ))
            .copyWith(
              title: _titleController.text.trim(),
              author: _authorController.text.trim(),
              category: _category,
              excerpt: _excerptController.text.trim(),
              content: content,
              paragraphs: paragraphs,
              readingMinutes: int.parse(_minutesController.text),
              updatedAt: now,
              coverColors: _coverColors(_category),
            );

    await widget.repository.upsertStory(updated);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Color(0xFF17152B)),
        ),
        title: Text(
          widget.story == null ? 'Create a story' : 'Edit story',
          style: const TextStyle(
            color: Color(0xFF17152B),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        children: [
          Center(
            child: Container(
              height: 130,
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _coverColors(_category).map(_color).toList(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_categoryIcon(_category), color: Colors.white, size: 35),
                  const SizedBox(height: 8),
                  Text(
                    _category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(label: 'Title'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    'Give your story a memorable title',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please add a title'
                      : null,
                ),
                const SizedBox(height: 18),
                _FieldLabel(label: 'Author'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _authorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Who wrote this story?'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please add an author'
                      : null,
                ),
                const SizedBox(height: 18),
                _FieldLabel(label: 'Category'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _categories.contains(_category)
                      ? _category
                      : _categories.first,
                  decoration: _inputDecoration('Choose a genre'),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 18),
                _FieldLabel(label: 'Reading time'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Minutes', suffix: 'min'),
                  validator: (value) {
                    final minutes = int.tryParse(value ?? '');
                    if (minutes == null || minutes < 1)
                      return 'Enter at least 1 minute';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                _FieldLabel(label: 'Short description'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _excerptController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration('A one or two sentence teaser'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please add a description'
                      : null,
                ),
                const SizedBox(height: 18),
                _FieldLabel(label: 'Story'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contentController,
                  minLines: 10,
                  maxLines: 20,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    'Write your story here. Separate paragraphs with a blank line.',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Please add story content';
                    if (value.trim().split(RegExp(r'\s+')).length < 20) {
                      return 'Please add a little more content';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _inputDecoration(String hint, {String? suffix}) =>
      InputDecoration(
        hintText: hint,
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Color(0xFF77748A), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      );

  static List<Color> _coverColors(String category) =>
      switch (category.toLowerCase()) {
        'science fiction' => const [Color(0xFF17233F), Color(0xFF5B5BD6)],
        'adventure' => const [Color(0xFF0F766E), Color(0xFFF59E0B)],
        'mystery' => const [Color(0xFF7C2D12), Color(0xFFF97316)],
        'fantasy' => const [Color(0xFF312E81), Color(0xFFDB2777)],
        'romance' => const [Color(0xFF831843), Color(0xFFEC4899)],
        _ => const [Color(0xFF4F46E5), Color(0xFF9333EA)],
      };

  static IconData _categoryIcon(String category) =>
      switch (category.toLowerCase()) {
        'science fiction' => Icons.rocket_launch_rounded,
        'adventure' => Icons.explore_rounded,
        'mystery' => Icons.search_rounded,
        'fantasy' => Icons.auto_stories_rounded,
        'romance' => Icons.favorite_rounded,
        _ => Icons.edit_note_rounded,
      };
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF17152B),
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    );
  }
}
