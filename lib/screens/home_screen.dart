import 'package:flutter/material.dart';
import 'package:my_stories/models/story.dart';
import 'package:my_stories/screens/story_detail_screen.dart';
import 'package:my_stories/screens/story_form_screen.dart';
import 'package:my_stories/services/story_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final StoryRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Story> _stories = const <Story>[];
  String _filter = 'All';
  bool _isLoading = true;
  bool _hasError = false;

  static const List<String> _filters = ['All', 'Favorites', 'Finished'];

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStories() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final stories = await widget.repository.loadStories();
      if (!mounted) return;
      setState(() {
        _stories = stories;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _refreshStory([Story? _]) async {
    final stories = await widget.repository.loadStories();
    if (!mounted) return;
    setState(() => _stories = stories);
  }

  Future<void> _openStory(Story story) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryDetailScreen(
          story: story,
          repository: widget.repository,
          onStoriesChanged: () => _refreshStory(story),
        ),
      ),
    );
    await _loadStories();
  }

  Future<void> _openForm([Story? story]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            StoryFormScreen(story: story, repository: widget.repository),
      ),
    );
    if (result == true) await _loadStories();
  }

  List<Story> get _visibleStories {
    final query = _searchController.text.trim().toLowerCase();
    return _stories.where((story) {
      final matchesFilter = switch (_filter) {
        'Favorites' => story.isFavorite,
        'Finished' => story.progressPercent >= 100,
        _ => true,
      };
      final matchesSearch =
          query.isEmpty ||
          story.title.toLowerCase().contains(query) ||
          story.author.toLowerCase().contains(query) ||
          story.category.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Widget build(BuildContext context) {
    final visibleStories = _visibleStories;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      body: RefreshIndicator(
        onRefresh: _loadStories,
        child: ListView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).padding.top + 24,
            bottom: 112,
          ),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSearch(),
            const SizedBox(height: 18),
            _buildFilters(),
            const SizedBox(height: 24),
            if (_isLoading)
              const _LoadingLibrary()
            else if (_hasError)
              _ErrorState(onRetry: _loadStories)
            else if (visibleStories.isEmpty)
              _EmptyState(onCreate: () => _openForm())
            else
              _buildGrid(visibleStories),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New story'),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good day, reader',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF17152B),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Your next favorite story is waiting.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF77748A)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search titles, authors, genres',
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF77748A)),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, color: Color(0xFF77748A)),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _filters.map((filter) {
        final selected = filter == _filter;
        return FilterChip(
          label: Text(filter),
          selected: selected,
          selectedColor: const Color(0xFF4F46E5),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: selected ? Colors.white : const Color(0xFF68657A),
            fontWeight: FontWeight.w700,
          ),
          onSelected: (_) => setState(() => _filter = filter),
        );
      }).toList(),
    );
  }

  Widget _buildGrid(List<Story> stories) {
    return _StoryGrid(stories: stories, onOpenStory: _openStory);
  }
}

class _LoadingLibrary extends StatelessWidget {
  const _LoadingLibrary();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _EmptyCard(
      icon: Icons.cloud_off_outlined,
      title: 'Stories could not be loaded',
      message: 'Check your device storage and try again.',
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _EmptyCard(
      icon: Icons.library_add_outlined,
      title: 'Your library is ready for a story',
      message:
          'Write a new tale or come back to this space whenever inspiration strikes.',
      actionLabel: 'Create a story',
      onAction: onCreate,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E6F5)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFF4F46E5)),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF17152B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 9),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF77748A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

// The story grid is kept in a separate widget so the library page stays readable.
class _StoryGrid extends StatelessWidget {
  const _StoryGrid({required this.stories, required this.onOpenStory});

  final List<Story> stories;
  final ValueChanged<Story> onOpenStory;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 920
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 0.78,
          ),
          itemCount: stories.length,
          itemBuilder: (context, index) => StoryCard(
            story: stories[index],
            onTap: () => onOpenStory(stories[index]),
          ),
        );
      },
    );
  }
}

class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 128,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: story.coverColors.length >= 2
                            ? [
                                _color(story.coverColors[0]),
                                _color(story.coverColors[1]),
                              ]
                            : [
                                const Color(0xFF4F46E5),
                                const Color(0xFF9B5DE5),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Icon(
                        _categoryIcon(story.category),
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 31,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(
                        story.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: story.isFavorite
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                story.category,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                story.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF17152B),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'by ${story.author}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF77748A)),
              ),
              const Spacer(),
              if (story.progressPercent > 0) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: story.progressPercent / 100,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: const Color(0xFFECEAF6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${story.progressPercent}% read',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF68657A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
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
}
