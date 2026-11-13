import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/island_bridge.dart';
import '../state/app_state.dart';
import 'glass.dart';
import 'library_pages.dart';
import 'now_playing.dart';
import 'settings_tab.dart';

class _FeaturedBand {
  const _FeaturedBand({
    required this.band,
    required this.album,
    required this.query,
    required this.colors,
  });

  final String band;
  final String album;
  final String query;
  final List<Color> colors;
}

const List<_FeaturedBand> _topBands = [
  _FeaturedBand(
    band: 'Stand Here Alone',
    album: 'Melawan Dunia',
    query: 'Stand Here Alone',
    colors: [Color(0xFF7F1D1D), Color(0xFF1F2937)],
  ),
  _FeaturedBand(
    band: 'Threesixty',
    album: 'Mimpi dan Harapan',
    query: 'Threesixty',
    colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
  ),
  _FeaturedBand(
    band: 'Denny Caknan',
    album: 'Kalih Welasku',
    query: 'Denny Caknan',
    colors: [Color(0xFF78350F), Color(0xFF1C1917)],
  ),
  _FeaturedBand(
    band: 'for Revenge',
    album: 'Perayaan Patah Hati - Babak 1',
    query: 'for Revenge',
    colors: [Color(0xFF4C1D95), Color(0xFF09090B)],
  ),
  _FeaturedBand(
    band: 'Last Child',
    album: 'Our Biggest Thing Ever',
    query: 'Last Child',
    colors: [Color(0xFF064E3B), Color(0xFF111827)],
  ),
];

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
  String? _selectedBand;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _searchBand(_FeaturedBand item, AppState s) {
    setState(() {
      _selectedBand = item.band;
      _ctrl.text = item.query;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
    s.search(item.query);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Beranda',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: IslandBridge.enabledNotifier,
                  builder: (context, enabled, _) {
                    return IconButton(
                      tooltip: enabled
                          ? 'Matikan Dynamic Island'
                          : 'Nyalakan Dynamic Island',
                      icon: Icon(
                        enabled ? Icons.layers_rounded : Icons.layers_outlined,
                        color: enabled
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white70,
                      ),
                      onPressed: () async {
                        final active = await IslandBridge.toggleFromUi();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              active
                                  ? 'Dynamic Island: ON'
                                  : 'Dynamic Island: OFF',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassBox(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _ctrl,
                builder: (_, val, __) {
                  return TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) {
                      setState(() => _selectedBand = null);
                      s.search(v);
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Cari lagu atau album di Spotify',
                      icon: const Icon(Icons.search),
                      suffixIcon: val.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _ctrl.clear();
                                setState(() => _selectedBand = null);
                              },
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'Top Album & Band',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _topBands.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final item = _topBands[i];
                final active = _selectedBand == item.band;
                return GestureDetector(
                  onTap: () => _searchBand(item, s),
                  child: SizedBox(
                    width: 156,
                    child: GlassBox(
                      radius: 18,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: item.colors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: active
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white24,
                                    width: active ? 1.5 : 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.album_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.play_circle_fill_rounded,
                                size: 22,
                                color: active
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white70,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.band,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.album,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (s.searching) const LinearProgressIndicator(),
          if (s.downloadingId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: LinearProgressIndicator(
                value: s.downloadProgress == 0 ? null : s.downloadProgress,
              ),
            ),
          Expanded(
            child: s.results.isEmpty && !s.searching
                ? const Center(
                    child: Text(
                      'Pilih band di atas atau cari lagu di Spotify',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: s.results.length,
                    itemBuilder: (_, i) {
                      final song = s.results[i];
                      return ListTile(
                        leading: ArtThumb(uri: song.artUri),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                        Text(
                          item.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
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
              child: Text(
                'Pilih playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
