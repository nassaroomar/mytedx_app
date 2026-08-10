import 'package:flutter/material.dart';

import '../widgets/expanded_player_view.dart';

/// Kept for compatibility; talk opens now go through the global mini-player.
class DetailsScreen extends StatelessWidget {
  const DetailsScreen({
    super.key,
    required this.talkId,
    this.previewTitle,
    this.previewImageUrl,
    this.previewPresenter,
  });

  final String talkId;
  final String? previewTitle;
  final String? previewImageUrl;
  final String? previewPresenter;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await openTalkInPlayer(
        context,
        talkId: talkId,
        previewTitle: previewTitle,
        previewImageUrl: previewImageUrl,
        previewPresenter: previewPresenter,
      );
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFE62B1E)),
      ),
    );
  }
}
