import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/talk.dart';
import '../services/local_history_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/library_viewmodel.dart';
import '../widgets/expanded_player_view.dart';
import '../widgets/talk_cover_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryViewModel>().load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _ProfileAccountHeader(),
            ),
            TabBar(
              controller: _tabs,
              indicatorColor: AppTheme.tedRed,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(text: 'History'),
                Tab(text: 'Watch later'),
              ],
            ),
            Expanded(
              child: Consumer<LibraryViewModel>(
                builder: (context, library, _) {
                  if (library.isLoading &&
                      library.history.isEmpty &&
                      library.watchLater.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.tedRed),
                    );
                  }

                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _HistoryTab(entries: library.history),
                      _WatchLaterTab(talks: library.watchLater),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAccountHeader extends StatelessWidget {
  const _ProfileAccountHeader();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final email = auth.email;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFF2A1212),
            child: Icon(Icons.person_rounded, color: AppTheme.tedRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signed in',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (email == null || email.isEmpty) ? 'MyTEDx account' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () async {
                    await auth.signOut();
                  },
            style: TextButton.styleFrom(foregroundColor: AppTheme.tedRed),
            child: auth.isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.tedRed,
                    ),
                  )
                : const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.entries});

  final List<WatchedTalkEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Videos you watch will appear here so you can continue later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.tedRed,
      onRefresh: () => context.read<LibraryViewModel>().refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _HistoryTile(entry: entry);
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final WatchedTalkEntry entry;

  @override
  Widget build(BuildContext context) {
    final progress = entry.progressFraction;

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openTalkInPlayer(
          context,
          talkId: entry.id,
          previewTitle: entry.title,
          previewImageUrl: entry.imageUrl,
          previewPresenter: entry.presenterDisplayName,
          resumePositionSeconds:
              entry.positionSeconds >= 2 ? entry.positionSeconds : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: entry.imageUrl.isNotEmpty
                      ? TalkCoverImage(
                          imageUrl: entry.imageUrl,
                          borderRadius: BorderRadius.zero,
                        )
                      : const ColoredBox(
                          color: AppTheme.surfaceElevated,
                          child: Icon(Icons.movie_outlined, color: AppTheme.tedRed),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.presenterDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: Colors.white12,
                        color: AppTheme.tedRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress <= 0
                          ? 'Not started'
                          : '${(progress * 100).round()}% watched',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchLaterTab extends StatelessWidget {
  const _WatchLaterTab({required this.talks});

  final List<Talk> talks;

  @override
  Widget build(BuildContext context) {
    if (talks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Save talks with the ⋮ menu next to the description to watch them later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.tedRed,
      onRefresh: () => context.read<LibraryViewModel>().refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: talks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final talk = talks[index];
          return Material(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => openTalkInPlayer(
                context,
                talkId: talk.id,
                previewTitle: talk.title,
                previewImageUrl: talk.imageUrl,
                previewPresenter: talk.presenterDisplayName,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 120,
                        height: 68,
                        child: talk.imageUrl.isNotEmpty
                            ? TalkCoverImage(
                                imageUrl: talk.imageUrl,
                                borderRadius: BorderRadius.zero,
                              )
                            : const ColoredBox(
                                color: AppTheme.surfaceElevated,
                                child: Icon(
                                  Icons.movie_outlined,
                                  color: AppTheme.tedRed,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        talk.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () => context
                          .read<LibraryViewModel>()
                          .removeFromWatchLater(talk.id),
                      icon: const Icon(
                        Icons.bookmark_remove_outlined,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
