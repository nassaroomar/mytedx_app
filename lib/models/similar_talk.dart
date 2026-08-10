import '../models/talk.dart';

/// A talk ranked by how many tags it shares with the current video.
class SimilarTalk {
  const SimilarTalk({
    required this.talk,
    required this.sharedTagCount,
    required this.sharedTags,
  });

  final Talk talk;
  final int sharedTagCount;
  final List<String> sharedTags;
}
