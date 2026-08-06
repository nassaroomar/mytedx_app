class RelatedTalk {
  final String relatedId;
  final String slug;
  final String title;
  final String duration;
  final String viewedCount;
  final String presenterDisplayName;
  final String? imageUrl;

  const RelatedTalk({
    required this.relatedId,
    required this.slug,
    required this.title,
    required this.duration,
    required this.viewedCount,
    required this.presenterDisplayName,
    this.imageUrl,
  });

  int get durationSeconds => int.tryParse(duration) ?? 0;

  String get formattedDuration {
    final total = durationSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get viewedCountValue => int.tryParse(viewedCount) ?? 0;

  factory RelatedTalk.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title']?.toString().trim();
    final rawPresenter = json['presenterDisplayName']?.toString().trim();
    final rawImage = (json['image_url'] ?? json['imageUrl'])?.toString().trim();

    return RelatedTalk(
      relatedId: (json['related_id'] ?? json['relatedId'] ?? json['id'])
              ?.toString() ??
          '',
      slug: json['slug']?.toString() ?? '',
      title: (rawTitle == null || rawTitle.isEmpty) ? 'Untitled Talk' : rawTitle,
      duration: json['duration']?.toString() ?? '0',
      viewedCount: (json['viewedCount'] ?? json['viewed_count'])?.toString() ??
          '0',
      presenterDisplayName:
          (rawPresenter == null || rawPresenter.isEmpty) ? 'Unknown' : rawPresenter,
      imageUrl: (rawImage == null || rawImage.isEmpty) ? null : rawImage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'related_id': relatedId,
      'slug': slug,
      'title': title,
      'duration': duration,
      'viewedCount': viewedCount,
      'presenterDisplayName': presenterDisplayName,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}
