import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'services/music_api.dart';
import 'services/music_handler.dart';
import 'state/app_state.dart';
import 'ui/home_shell.dart';
import 'ui/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = MusicApi();
  final handler = await AudioService.init(
    builder: () => MusicHandler(api),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.singo.tune.playback',
      androidNotificationChannelName: 'Pemutar musik',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
      androidStopOnRemoveTask: false,
    ),
  );
  final state = AppState(api: api, handler: handler);
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const GlassMusicApp()));
}

class GlassMusicApp extends StatelessWidget {
  const GlassMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AppState, bool>((s) => s.loggedIn);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8B5CF6),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: loggedIn ? const HomeShell() : const LoginPage(),
    );
  }
}
