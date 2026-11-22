class ComicItem {
  final String sourceId;
  final String title;
  final String url;
  final String cover;
  final String latestChapter;

  const ComicItem({
    required this.sourceId,
    required this.title,
    required this.url,
    required this.cover,
    this.latestChapter = '',
  });

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'title': title,
        'url': url,
        'cover': cover,
        'latestChapter': latestChapter,
      };

  factory ComicItem.fromJson(Map<String, dynamic> json) => ComicItem(
        sourceId: json['sourceId'] ?? 'dm5',
        title: json['title'] ?? '',
        url: json['url'] ?? '',
        cover: json['cover'] ?? '',
        latestChapter: json['latestChapter'] ?? '',
      );
}

class ComicChapter {
  final String title;
  final String url;

  const ComicChapter({required this.title, required this.url});
}

class ComicDetail {
  final ComicItem item;
  final String author;
  final String description;
  final List<ComicChapter> chapters;

  const ComicDetail({
    required this.item,
    required this.author,
    required this.description,
    required this.chapters,
  });
}
