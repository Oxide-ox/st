import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'glass.dart';

Future<void> showNowPlaying(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const NowPlayingPage()),
  );
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.read<AppState>().handler;
    return StreamBuilder<MediaItem?>(
      stream: h.mediaItem,
      builder: (_, snap) {
        final item = snap.data;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: AlbumBackdrop(art: item?.artUri)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Spacer(),
                      ArtThumb(uri: item?.artUri, size: 280),
                      const SizedBox(height: 24),
                      Text(item?.title ?? '',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(item?.artist ?? '', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      StreamBuilder<PlaybackState>(
                        stream: h.playbackState,
                        builder: (_, ps) {
                          final playing = ps.data?.playing ?? false;
                          return GlassBox(
                            radius: 60,
                            padding: const EdgeInsets.all(8),
                            child: IconButton(
                              iconSize: 56,
                              icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                              onPressed: () => playing ? h.pause() : h.play(),
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
