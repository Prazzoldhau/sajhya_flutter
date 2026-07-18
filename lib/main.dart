import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';   // 👈 start with SplashScreen
import 'screens/video_player_screen.dart';

// Optional demo entry: build/run with
//   --dart-define=DEMO_VIDEO=https://youtu.be/luBcCqIwrOg
// to open straight into the exercise player (no login) for previewing the
// patient video experience. Empty (the default) keeps normal startup.
const String _demoVideo = String.fromEnvironment('DEMO_VIDEO');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sajhya',
      theme: AppTheme.lightTheme,
      home: _demoVideo.isNotEmpty
          ? VideoPlayerScreen(
              playlist: [
                ExerciseVideo.fromUrl('Demo exercise', _demoVideo),
              ],
            )
          : const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
