import 'package:flutter/material.dart';

@immutable
class Story {
  const Story({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.excerpt,
    required this.content,
    required this.paragraphs,
    required this.readingMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.authorId = '',
    this.authorName = '',
    this.authorPhoto,
    this.isAnonymous = false,
    this.tags = const [],
    this.coverImageUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.isPublished = true,
    this.isFavorite = false,
    this.progressPercent = 0,
    this.coverColors = const ['#5B5BD6', '#9B5DE5'],
  });

  final String id;
  final String title;
  final String author;
  final String category;
  final String excerpt;
  final String content;
  final List<String> paragraphs;
  final int readingMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final bool isAnonymous;
  final List<String> tags;
  final String? coverImageUrl;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool isPublished;
  final bool isFavorite;
  final int progressPercent;
  final List<String> coverColors;

  Story copyWith({
    String? id,
    String? title,
    String? author,
    String? category,
    String? excerpt,
    String? content,
    List<String>? paragraphs,
    int? readingMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorId,
    String? authorName,
    String? authorPhoto,
    bool? isAnonymous,
    List<String>? tags,
    String? coverImageUrl,
    int? likeCount,
    int? commentCount,
    int? viewCount,
    bool? isPublished,
    bool? isFavorite,
    int? progressPercent,
    List<String>? coverColors,
  }) {
    return Story(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      category: category ?? this.category,
      excerpt: excerpt ?? this.excerpt,
      content: content ?? this.content,
      paragraphs: paragraphs ?? this.paragraphs,
      readingMinutes: readingMinutes ?? this.readingMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhoto: authorPhoto ?? this.authorPhoto,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      tags: tags ?? this.tags,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount ?? this.viewCount,
      isPublished: isPublished ?? this.isPublished,
      isFavorite: isFavorite ?? this.isFavorite,
      progressPercent: progressPercent ?? this.progressPercent,
      coverColors: coverColors ?? this.coverColors,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'authorName': authorName.isEmpty ? author : authorName,
    'category': category,
    'excerpt': excerpt,
    'content': content,
    'paragraphs': paragraphs,
    'readingMinutes': readingMinutes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'authorId': authorId,
    'authorPhoto': authorPhoto,
    'isAnonymous': isAnonymous,
    'tags': tags,
    'coverImageUrl': coverImageUrl,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'viewCount': viewCount,
    'isPublished': isPublished,
    'isFavorite': isFavorite,
    'progressPercent': progressPercent,
    'coverColors': coverColors,
  };

  factory Story.fromJson(Map<String, dynamic> json) {
    final paragraphsJson = json['paragraphs'];
    final content = json['content'] as String? ?? '';
    final paragraphs = paragraphsJson is List
        ? paragraphsJson.whereType<String>().toList()
        : content
              .split(RegExp(r'\n\s*\n'))
              .map((paragraph) => paragraph.trim())
              .where((paragraph) => paragraph.isNotEmpty)
              .toList();

    final coverColors = json['coverColors'];
    final normalizedProgress = (json['progressPercent'] as num?)?.toInt() ?? 0;

    final tags = <String>[];
    final rawTags = json['tags'];
    if (rawTags is List) {
      for (final rawTag in rawTags) {
        if (rawTag is String) {
          final tag = rawTag.trim().toLowerCase();
          if (tag.isNotEmpty) {
            tags.add(tag);
          }
        }
      }
    }

    final author =
        json['author'] as String? ??
        json['authorName'] as String? ??
        'Unknown author';
    final authorName =
        (json['authorName'] as String?)?.trim().isNotEmpty == true
        ? json['authorName'] as String
        : author;
    final authorId = json['authorId'] as String? ?? '';

    return Story(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled story',
      author: author,
      category: json['category'] as String? ?? 'General',
      excerpt: json['excerpt'] as String? ?? content,
      content: content,
      paragraphs: paragraphs,
      readingMinutes: (json['readingMinutes'] as num?)?.toInt() ?? 1,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      authorId: authorId,
      authorName: authorName,
      authorPhoto: json['authorPhoto'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      tags: tags,
      coverImageUrl: json['coverImageUrl'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      isPublished: json['isPublished'] as bool? ?? true,
      isFavorite: json['isFavorite'] as bool? ?? false,
      progressPercent: normalizedProgress.clamp(0, 100),
      coverColors: coverColors is List
          ? coverColors.whereType<String>().toList()
          : const ['#5B5BD6', '#9B5DE5'],
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }
}

class StorySeed {
  static List<Story> all() => [
    Story(
      id: 'lighthouse-tomorrow',
      title: 'The Lighthouse at the Edge of Tomorrow',
      author: 'Ava Sinclair',
      category: 'Science Fiction',
      excerpt:
          'When the sea begins to glow, a keeper discovers that the light is not warning ships away—it is calling them home.',
      content:
          'The lighthouse had stood on the black rocks for longer than anyone in Port Mercy could remember. Every evening, Mara climbed the spiral stairs and lit the lamp, trusting its steady beam to guide strangers through the fog.\n\nOne November night, the sea below the cliff began to shine. The glow moved beneath the waves like a second constellation, bright enough to turn the foam silver. Mara watched a fishing boat change course toward the light, its crew waving as if they had seen an old friend.\n\nShe descended to the shore and found a glass sphere resting in the tideline. Inside it, a tiny storm turned slowly around a golden star. When Mara touched the glass, she heard a voice speaking from the future, asking her to keep the lamp burning for one more night.\n\nBy morning, three ships had reached the harbor safely, and every sailor told the same impossible story: the lighthouse had shown them the way home before they were lost.',
      paragraphs: [
        'The lighthouse had stood on the black rocks for longer than anyone in Port Mercy could remember. Every evening, Mara climbed the spiral stairs and lit the lamp, trusting its steady beam to guide strangers through the fog.',
        'One November night, the sea below the cliff began to shine. The glow moved beneath the waves like a second constellation, bright enough to turn the foam silver. Mara watched a fishing boat change course toward the light, its crew waving as if they had seen an old friend.',
        'She descended to the shore and found a glass sphere resting in the tideline. Inside it, a tiny storm turned slowly around a golden star. When Mara touched the glass, she heard a voice speaking from the future, asking her to keep the lamp burning for one more night.',
        'By morning, three ships had reached the harbor safely, and every sailor told the same impossible story: the lighthouse had shown them the way home before they were lost.',
      ],
      readingMinutes: 4,
      createdAt: DateTime(2025, 8, 12),
      updatedAt: DateTime(2025, 8, 12),
      coverColors: ['#17233F', '#5B5BD6'],
    ),
    Story(
      id: 'small-wonders',
      title: 'A Map of Small Wonders',
      author: 'Theo Nguyen',
      category: 'Adventure',
      excerpt:
          'A retired cartographer follows a child’s doodle across the city and finds a world hidden in plain sight.',
      content:
          'Elias had spent forty years drawing mountains, rivers, and borders for people who wanted the world to feel manageable. On the day he retired, a girl left a folded page in his studio. It showed his street, but the bakery was labeled “dragon gate” and the bus stop was marked “cloud ferry.”\n\nHe followed the map because it was the first new place he had found in years. Behind the bakery, a narrow alley opened onto a courtyard where paper cranes moved in the breeze. At the bus stop, the driver knew his name and handed him a ticket stamped with tomorrow’s date.\n\nThe final mark on the map was Elias’s own front door. Inside, he found a blank atlas waiting on his desk. Its first page was already filled with a single sentence: every journey begins when you decide to look again.',
      paragraphs: [
        'Elias had spent forty years drawing mountains, rivers, and borders for people who wanted the world to feel manageable. On the day he retired, a girl left a folded page in his studio. It showed his street, but the bakery was labeled “dragon gate” and the bus stop was marked “cloud ferry.”',
        'He followed the map because it was the first new place he had found in years. Behind the bakery, a narrow alley opened onto a courtyard where paper cranes moved in the breeze. At the bus stop, the driver knew his name and handed him a ticket stamped with tomorrow’s date.',
        'The final mark on the map was Elias’s own front door. Inside, he found a blank atlas waiting on his desk. Its first page was already filled with a single sentence: every journey begins when you decide to look again.',
      ],
      readingMinutes: 3,
      createdAt: DateTime(2025, 7, 24),
      updatedAt: DateTime(2025, 7, 24),
      coverColors: ['#0F766E', '#F59E0B'],
    ),
    Story(
      id: 'bakers-secret',
      title: 'The Baker’s Secret',
      author: 'Mira Patel',
      category: 'Mystery',
      excerpt:
          'The best bread in the market has one unusual ingredient: a memory from the person who needs it most.',
      content:
          'Every Thursday, Nisha baked twelve loaves and sold eleven. The last loaf always went into a blue paper bag, but no customer ever came to collect it. The people of Willow Lane had learned not to ask questions about the bakery after sunset.\n\nWhen a stranger arrived with a photograph of the missing loaf, Nisha finally told the truth. Her grandmother had taught her to bake with memories: a laugh for courage, a lullaby for sleep, a rainy afternoon for anyone who had forgotten how to rest.\n\nThe blue bag was not for a customer. It was for the town itself. Each week, Nisha left it on the bench beneath the clock, where someone in need would find it before they knew they were lost.',
      paragraphs: [
        'Every Thursday, Nisha baked twelve loaves and sold eleven. The last loaf always went into a blue paper bag, but no customer ever came to collect it. The people of Willow Lane had learned not to ask questions about the bakery after sunset.',
        'When a stranger arrived with a photograph of the missing loaf, Nisha finally told the truth. Her grandmother had taught her to bake with memories: a laugh for courage, a lullaby for sleep, a rainy afternoon for anyone who had forgotten how to rest.',
        'The blue bag was not for a customer. It was for the town itself. Each week, Nisha left it on the bench beneath the clock, where someone in need would find it before they knew they were lost.',
      ],
      readingMinutes: 3,
      createdAt: DateTime(2025, 6, 18),
      updatedAt: DateTime(2025, 6, 18),
      coverColors: ['#7C2D12', '#F97316'],
    ),
    Story(
      id: 'last-library',
      title: 'The Last Library',
      author: 'Jonas Reed',
      category: 'Fantasy',
      excerpt:
          'In a city where stories are traded for years of life, one librarian refuses to let the final book close.',
      content:
          'The Library of Hours occupied seven floors and one impossible corridor. Its shelves held every story ever told, but the price of borrowing a book was measured in time. A poem might cost an afternoon; a novel could take a decade.\n\nLiora worked at the circulation desk and knew the weight of every bargain. When a boy asked for a book about his late mother, she saw that he had only one hour left to spend. She slipped him a blank notebook instead and told him to write the story himself.\n\nThat night, the library lights burned until dawn. In the morning, a new shelf had appeared, filled with books whose pages were still warm. The final book on the end was open to a sentence Liora had never read before: some stories are not taken from us—they are returned.',
      paragraphs: [
        'The Library of Hours occupied seven floors and one impossible corridor. Its shelves held every story ever told, but the price of borrowing a book was measured in time. A poem might cost an afternoon; a novel could take a decade.',
        'Liora worked at the circulation desk and knew the weight of every bargain. When a boy asked for a book about his late mother, she saw that he had only one hour left to spend. She slipped him a blank notebook instead and told him to write the story himself.',
        'That night, the library lights burned until dawn. In the morning, a new shelf had appeared, filled with books whose pages were still warm. The final book on the end was open to a sentence Liora had never read before: some stories are not taken from us—they are returned.',
      ],
      readingMinutes: 4,
      createdAt: DateTime(2025, 5, 9),
      updatedAt: DateTime(2025, 5, 9),
      coverColors: ['#312E81', '#DB2777'],
    ),
  ];
}
