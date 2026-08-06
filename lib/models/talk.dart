class Talk {
  final String id;
  final String title;
  final String duration;
  final String presenterDisplayName;
  final String imageUrl;

  const Talk({
    required this.id,
    required this.title,
    required this.duration,
    required this.presenterDisplayName,
    required this.imageUrl,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'presenterDisplayName': presenterDisplayName,
      'image_url': imageUrl,
    };
  }
}
