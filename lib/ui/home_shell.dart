import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../state/app_state.dart';
import 'glass.dart';
import 'library_pages.dart';
import 'now_playing.dart';
import 'settings_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final h = context.read<AppState>().handler;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<MediaItem?>(
        stream: h.mediaItem,
        builder: (_, snap) => Stack(
          children: [
            Positioned.fill(child: AlbumBackdrop(art: snap.data?.artUri)),
            Positioned.fill(
              child: IndexedStack(
                index: _tab,
                children: const [SearchTab(), LibraryTab(), SettingsTab()],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search), label: 'Cari'),
              NavigationDestination(icon: Icon(Icons.library_music), label: 'Playlist'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Setting'),
            ],
          ),
        ],
      ),
    );
  }
}

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Beranda', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassBox(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => s.search(v),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Cari lagu di Spotify',
                  icon: Icon(Icons.search),
                ),
              ),
            ),
          ),
          if (s.searching) const LinearProgressIndicator(),
          if (s.downloadingId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: LinearProgressIndicator(
                value: s.downloadProgress == 0 ? null : s.downloadProgress,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: s.results.length,
              itemBuilder: (_, i) {
                final song = s.results[i];
                return ListTile(
                  leading: ArtThumb(uri: song.artUri),
                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => showSongActions(context, song),
                  ),
                  onTap: () => s.play(song),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.read<AppState>().handler;
    return StreamBuilder<MediaItem?>(
      stream: h.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: GestureDetector(
            onTap: () => showNowPlaying(context),
            child: GlassBox(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  ArtThumb(uri: item.artUri, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(item.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  StreamBuilder<PlaybackState>(
                    stream: h.playbackState,
                    builder: (_, ps) {
                      final playing = ps.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: () => playing ? h.pause() : h.play(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showSongActions(BuildContext context, Song song) {
  final s = context.read<AppState>();
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(12),
      child: GlassBox(
        radius: 24,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ArtThumb(uri: song.artUri),
              title: Text(song.title),
              subtitle: Text(song.artist),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Tambah ke playlist'),
              onTap: () {
                Navigator.pop(ctx);
                pickPlaylist(context, (p) => s.addSong(p, song));
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download ke playlist'),
              onTap: () {
                Navigator.pop(ctx);
                pickPlaylist(context, (p) => s.downloadInto(p, song));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> pickPlaylist(
  BuildContext context,
  Future<void> Function(Playlist) onPick,
) {
  final playlists = context.read<AppState>().playlists;
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(12),
      child: GlassBox(
        radius: 24,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Pilih playlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final p in playlists)
              ListTile(
                title: Text(p.name),
                subtitle: Text('${p.songs.length} lagu'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onPick(p);
                },
              ),
          ],
        ),
      ),
    ),
  );
}
