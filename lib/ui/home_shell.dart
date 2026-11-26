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
              NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Beranda'),
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
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
                Expanded(
                  child: Text(
                    _greeting(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Perbarui rekomendasi',
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white70,
                    size: 21,
                  ),
                  onPressed: () => s.loadRecommendations(forceRefresh: true),
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
                    onSubmitted: (v) => s.search(v),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Cari lagu, artis, atau album...',
                      icon: const Icon(Icons.search),
                      suffixIcon: val.text.isEmpty && s.results.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _ctrl.clear();
                                s.clearResults();
                              },
                            ),
                    ),
                  );
                },
              ),
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
                ? _SpotifyHomeDashboard(state: s)
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
                        onTap: () => s.play(song, queue: s.results),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpotifyHomeDashboard extends StatelessWidget {
  const _SpotifyHomeDashboard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final quickSongs = state.quickGridSongs;
    final shelves = state.dashboardFilter == 'Mix'
        ? state.spotifyShelves.where((s) => s.title.contains('Mix')).toList()
        : state.spotifyShelves;

    return RefreshIndicator(
      color: const Color(0xFF1DB954),
      onRefresh: () => state.loadRecommendations(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          Row(
            children: ['Semua', 'Musik', 'Mix'].map((label) {
              final selected = state.dashboardFilter == label;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: const Color(0xFF1DB954),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  onSelected: (_) => state.setDashboardFilter(label),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          if (quickSongs.isNotEmpty && state.dashboardFilter != 'Mix') ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: quickSongs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 56,
              ),
              itemBuilder: (_, i) {
                final song = quickSongs[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => state.play(song, queue: quickSongs),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        ArtThumb(uri: song.artUri, size: 56),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
          ],
          if (state.recentSongs.isNotEmpty && state.dashboardFilter == 'Semua') ...[
            const Text(
              'Baru saja diputar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 156,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.recentSongs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final song = state.recentSongs[i];
                  return _SpotifySquareCard(
                    song: song,
                    size: 112,
                    onTap: () => state.play(song, queue: state.recentSongs),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
          ],
          if (state.loadingRecommendations)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1DB954)),
              ),
            )
          else
            ...shelves.map(
              (shelf) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shelf.subtitle != null)
                      Text(
                        shelf.subtitle!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    Text(
                      shelf.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 186,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: shelf.songs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) {
                          final song = shelf.songs[i];
                          return _SpotifySquareCard(
                            song: song,
                            size: 138,
                            onTap: () => state.play(song, queue: shelf.songs),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotifySquareCard extends StatelessWidget {
  const _SpotifySquareCard({
    required this.song,
    required this.size,
    required this.onTap,
  });

  final Song song;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ArtThumb(uri: song.artUri, size: size),
            ),
            const SizedBox(height: 7),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
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
