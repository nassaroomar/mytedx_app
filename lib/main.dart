import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/local_history_service.dart';
import 'services/recommendation_service.dart';
import 'services/api_service.dart';
import 'services/talk_tags_cache.dart';
import 'theme/app_theme.dart';
import 'viewmodels/details_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/library_viewmodel.dart';
import 'viewmodels/search_viewmodel.dart';
import 'viewmodels/video_player_provider.dart';
import 'views/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyTEDxApp());
}

class MyTEDxApp extends StatelessWidget {
  const MyTEDxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    final localHistory = LocalHistoryService();
    final recommendations = RecommendationService(
      apiService: api,
      localHistory: localHistory,
    );

    return MultiProvider(
      providers: [
        Provider.value(value: localHistory),
        Provider.value(value: api),
        ChangeNotifierProvider(
          create: (_) => TalkTagsCache(apiService: api),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(
            apiService: api,
            localHistory: localHistory,
            recommendations: recommendations,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SearchViewModel(
            apiService: api,
            localHistory: localHistory,
            recommendations: recommendations,
            homeShownIdsProvider: () => context.read<HomeViewModel>().shownIds,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LibraryViewModel(localHistory: localHistory),
        ),
        ChangeNotifierProvider(
          create: (_) => DetailsViewModel(
            apiService: api,
            recommendations: recommendations,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => VideoPlayerProvider(localHistory: localHistory),
        ),
      ],
      child: MaterialApp(
        title: 'MyTEDx',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const MainScreen(),
      ),
    );
  }
}
