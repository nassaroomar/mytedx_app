import 'related_talk.dart';

class TalkDetails {
  final String id;
  final String slug;
  final String title;
  final String description;
  final String duration;
  final String presenterDisplayName;
  final DateTime? publishedAt;
  final String imageUrl;
  final String? videoUrl;
  final List<String> tagsList;
  final List<RelatedTalk> relatedVideos;

  const TalkDetails({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.duration,
    required this.presenterDisplayName,
    required this.publishedAt,
    required this.imageUrl,
    required this.videoUrl,
    required this.tagsList,
    required this.relatedVideos,
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

  /// True when [videoUrl] looks like a direct media stream (mp4/m3u8/etc).
  bool get hasPlayableVideoUrl {
    final url = videoUrl?.trim() ?? '';
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }
    final path = uri.path.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.m3u8') ||
        path.endsWith('.mov') ||
        path.endsWith('.webm');
  }

  factory TalkDetails.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['publishedAt']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate);
    }

    final rawTags = json['tags_list'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final tag in rawTags) {
        if (tag != null) {
          final value = tag.toString().trim();
          if (value.isNotEmpty) {
            tags.add(value);
          }
        }
      }
    }

    final rawRelated = json['related_videos'];
    final related = <RelatedTalk>[];
    if (rawRelated is List) {
      for (final item in rawRelated) {
        if (item is Map) {
          related.add(
            RelatedTalk.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawTitle = json['title']?.toString().trim();
    final rawPresenter = json['presenterDisplayName']?.toString().trim();
    final rawImage = (json['image_url'] ?? json['imageUrl'])?.toString().trim();
    final rawVideo = (json['video_url'] ?? json['videoUrl'])?.toString().trim();

    return TalkDetails(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: (rawTitle == null || rawTitle.isEmpty) ? 'Untitled Talk' : rawTitle,
      description: json['description']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '0',
      presenterDisplayName:
          (rawPresenter == null || rawPresenter.isEmpty) ? 'Unknown' : rawPresenter,
      publishedAt: parsedDate,
      imageUrl: rawImage ?? '',
      videoUrl: (rawVideo == null || rawVideo.isEmpty) ? null : rawVideo,
      tagsList: tags,
      relatedVideos: related,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'description': description,
      'duration': duration,
      'presenterDisplayName': presenterDisplayName,
      'publishedAt': publishedAt?.toIso8601String(),
      'image_url': imageUrl,
      'video_url': videoUrl,
      'tags_list': tagsList,
      'related_videos': relatedVideos.map((item) => item.toJson()).toList(),
    };
  }
}
