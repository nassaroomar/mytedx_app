class Talk {
  final String id;
  final String title;
  final String duration;
  final String presenterDisplayName;
  final String imageUrl;
  final List<String> tagsList;

  const Talk({
    required this.id,
    required this.title,
    required this.duration,
    required this.presenterDisplayName,
    required this.imageUrl,
    this.tagsList = const [],
  });

  /// Duration in seconds, parsed safely from the API string.
  int get durationSeconds => int.tryParse(duration) ?? 0;

  /// Formatted duration like `17:39`.
  String get formattedDuration {
    final total = durationSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static List<String> _parseTags(dynamic rawTags) {
    final tags = <String>[];
    if (rawTags is! List) return tags;
    final seen = <String>{};
    for (final item in rawTags) {
      final value = item?.toString().trim() ?? '';
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      tags.add(value);
    }
    return tags;
  }

  factory Talk.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title']?.toString().trim();
    final rawPresenter = json['presenterDisplayName']?.toString().trim();
    final rawImage = (json['image_url'] ?? json['imageUrl'])?.toString().trim();

    return Talk(
      id: json['id']?.toString() ?? '',
      title: (rawTitle == null || rawTitle.isEmpty) ? 'Untitled Talk' : rawTitle,
      duration: json['duration']?.toString() ?? '0',
      presenterDisplayName:
          (rawPresenter == null || rawPresenter.isEmpty) ? 'Unknown' : rawPresenter,
      imageUrl: rawImage ?? '',
      tagsList: _parseTags(json['tags_list'] ?? json['tagsList'] ?? json['tags']),
    );
  }

  Talk copyWith({
    String? id,
    String? title,
    String? duration,
    String? presenterDisplayName,
    String? imageUrl,
    List<String>? tagsList,
  }) {
    return Talk(
      id: id ?? this.id,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      presenterDisplayName: presenterDisplayName ?? this.presenterDisplayName,
      imageUrl: imageUrl ?? this.imageUrl,
      tagsList: tagsList ?? this.tagsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'presenterDisplayName': presenterDisplayName,
      'image_url': imageUrl,
      'tags_list': tagsList,
    };
  }
}
