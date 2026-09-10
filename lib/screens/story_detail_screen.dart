import 'package:flutter/material.dart';
import 'package:my_stories/models/story.dart';
import 'package:my_stories/services/story_repository.dart';

class StoryDetailScreen extends StatefulWidget {
  const StoryDetailScreen({
    super.key,
    required this.story,
    required this.repository,
    required this.onStoriesChanged,
  });

  final Story story;
  final StoryRepository repository;
  final VoidCallback onStoriesChanged;

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late Story _story;

  @override
  void initState() {
    super.initState();
    _story = widget.story;
  }

  Future<void> _toggleFavorite() async {
    final updated = await widget.repository.toggleFavorite(_story);
    if (!mounted) return;
    setState(() => _story = updated);
    widget.onStoriesChanged();
  }

  Future<void> _updateProgress(int value) async {
    final updated = await widget.repository.updateProgress(_story, value);
    if (!mounted) return;
    setState(() => _story = updated);
    widget.onStoriesChanged();
  }

  Future<void> _deleteStory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this story?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await widget.repository.deleteStory(_story.id);
    if (!mounted) return;
    widget.onStoriesChanged();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMeta(),
                      const SizedBox(height: 28),
                      _buildProgressCard(),
                      const SizedBox(height: 30),
                      Text(
                        _story.title,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF17152B),
                              height: 1.08,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _story.excerpt,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF77748A),
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 36),
                      const Divider(color: Color(0xFFE5E1F2), thickness: 1),
                      const SizedBox(height: 30),
                      ..._story.paragraphs.map(
                        (paragraph) => Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: Text(
                            paragraph,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: const Color(0xFF464358),
                                  height: 1.8,
                                  fontSize: 17,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          '•  •  •',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: const Color(0xFFB8B4C9)),
                        ),
                      ),
                      const SizedBox(height: 34),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF4F46E5),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
      actions: [
        IconButton(
          onPressed: _toggleFavorite,
          icon: Icon(
            _story.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: Colors.white,
          ),
        ),
        IconButton(
          onPressed: _deleteStory,
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _story.coverColors.length >= 2
                  ? [
                      _color(_story.coverColors[0]),
                      _color(_story.coverColors[1]),
                    ]
                  : [const Color(0xFF4F46E5), const Color(0xFF9B5DE5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  _story.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeta() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFE9E6F5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _categoryIcon(_story.category),
            color: const Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _story.author,
                style: const TextStyle(
                  color: Color(0xFF17152B),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                '${_story.readingMinutes} min read · Updated ${_formattedDate(_story.updatedAt)}',
                style: const TextStyle(color: Color(0xFF77748A), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E6F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.track_changes_rounded,
                color: Color(0xFF4F46E5),
                size: 21,
              ),
              const SizedBox(width: 9),
              const Text(
                'Reading progress',
                style: TextStyle(
                  color: Color(0xFF17152B),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '${_story.progressPercent}%',
                style: const TextStyle(
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF4F46E5),
              inactiveTrackColor: const Color(0xFFECEAF6),
              thumbColor: const Color(0xFF4F46E5),
              trackHeight: 6,
            ),
            child: Slider(
              value: _story.progressPercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (value) => _updateProgress(value.round()),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => _updateProgress(0),
                child: const Text('Restart'),
              ),
              FilledButton.tonal(
                onPressed: _story.progressPercent >= 100
                    ? null
                    : () => _updateProgress(100),
                child: Text(
                  _story.progressPercent >= 100
                      ? 'Finished'
                      : 'Mark as finished',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _color(String value) =>
      Color(int.parse(value.replaceFirst('#', '0xFF')));

  static IconData _categoryIcon(String category) =>
      switch (category.toLowerCase()) {
        'science fiction' => Icons.rocket_launch_rounded,
        'adventure' => Icons.explore_rounded,
        'mystery' => Icons.search_rounded,
        'fantasy' => Icons.auto_stories_rounded,
        'romance' => Icons.favorite_rounded,
        _ => Icons.menu_book_rounded,
      };

  static String _formattedDate(DateTime date) =>
      '${date.day} ${_month(date.month)} ${date.year}';

  static String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}
