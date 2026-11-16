import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'glass.dart';
import 'home_shell.dart';

Future<void> showNowPlaying(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const NowPlayingPage(),
    ),
  );
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  double? _dragMs;
  String? _checkedItemId;
  bool _showLyrics = true;

  String _fmt(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = (totalSec ~/ 60).toString();
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int _findActiveLyricIndex(List<LyricLine> lyrics, Duration pos) {
    if (lyrics.isEmpty) return -1;
    int active = -1;
    for (int i = 0; i < lyrics.length; i++) {
      if (pos >= lyrics[i].time) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  void _ensureLyricsLoaded(AppState state, MediaItem item) {
    if (_checkedItemId == item.id) return;
    _checkedItemId = item.id;
    if (!state.isLoadingLyrics && state.syncedLyrics.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        state.fetchSyncedLyrics(item.title, item.artist ?? '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final h = state.handler;

    return StreamBuilder<MediaItem?>(
      stream: h.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _ensureLyricsLoaded(state, item);
        final currentSong = h.currentSong;
        final sourceLabel = (item.album != null && item.album!.trim().isNotEmpty)
            ? item.album!
            : (item.artist?.isNotEmpty == true ? item.artist! : 'Singo Tune');

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(child: AlbumBackdrop(art: item.artUri)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // Baris atas: tombol turun (v), sumber putar di tengah, titik tiga (⋮)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'PUTAR DARI SINGO TUNE',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sourceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white,
                            ),
                            onPressed: currentSong == null
                                ? null
                                : () => showSongActions(context, currentSong),
                          ),
                        ],
                      ),
                    ),

                    // Isi halaman yang bisa di-scroll ke bawah untuk melihat lirik
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Cover album kotak besar berpinggir melengkung
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 28,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: item.artUri == null
                                      ? const ColoredBox(
                                          color: Color(0xFF1F1635),
                                          child: Icon(
                                            Icons.music_note_rounded,
                                            color: Colors.white54,
                                            size: 84,
                                          ),
                                        )
                                      : ArtThumb(uri: item.artUri, size: 420),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),

                            // Judul & artis rata kiri + tombol (+) tambah ke playlist di kanan
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 21,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.artist ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  tooltip: 'Tambah ke playlist',
                                  icon: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  onPressed: currentSong == null
                                      ? null
                                      : () => pickPlaylist(
                                            context,
                                            (p) => state.addSong(p, currentSong),
                                          ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Seekbar durasi & 5 tombol kontrol Spotify
                            StreamBuilder<PlaybackState>(
                              stream: h.playbackState,
                              builder: (context, psSnap) {
                                final ps = psSnap.data;
                                final playing = ps?.playing ?? false;
                                final isShuffle = ps?.shuffleMode ==
                                    AudioServiceShuffleMode.all;
                                final isAutoNext = h.autoNext;

                                return StreamBuilder<Duration>(
                                  stream: AudioService.position,
                                  builder: (context, posSnap) {
                                    final pos = posSnap.data ?? Duration.zero;
                                    final total = item.duration ?? Duration.zero;
                                    final maxMs = total.inMilliseconds > 0
                                        ? total.inMilliseconds.toDouble()
                                        : 1.0;
                                    final currentMs = (_dragMs ??
                                            pos.inMilliseconds.toDouble())
                                        .clamp(0.0, maxMs);

                                    return Column(
                                      children: [
                                        SliderTheme(
                                          data: SliderThemeData(
                                            trackHeight: 3.2,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                              enabledThumbRadius: 5.5,
                                            ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                              overlayRadius: 12,
                                            ),
                                            activeTrackColor: Colors.white,
                                            inactiveTrackColor: Colors.white
                                                .withValues(alpha: 0.24),
                                            thumbColor: Colors.white,
                                          ),
                                          child: Slider(
                                            min: 0.0,
                                            max: maxMs,
                                            value: currentMs,
                                            onChanged: total.inMilliseconds <= 0
                                                ? null
                                                : (v) =>
                                                    setState(() => _dragMs = v),
                                            onChangeEnd:
                                                total.inMilliseconds <= 0
                                                    ? null
                                                    : (v) {
                                                        setState(
                                                            () => _dragMs = null);
                                                        h.seek(
                                                          Duration(
                                                            milliseconds:
                                                                v.round(),
                                                          ),
                                                        );
                                                      },
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _fmt(
                                                  Duration(
                                                    milliseconds:
                                                        currentMs.round(),
                                                  ),
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                              Text(
                                                _fmt(total),
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            IconButton(
                                              tooltip: 'Acak',
                                              icon: Icon(
                                                Icons.shuffle_rounded,
                                                color: isShuffle
                                                    ? const Color(0xFF1DB954)
                                                    : Colors.white70,
                                                size: 24,
                                              ),
                                              onPressed: () =>
                                                  h.customAction('shuffle'),
                                            ),
                                            IconButton(
                                              tooltip: 'Sebelumnya',
                                              icon: const Icon(
                                                Icons.skip_previous_rounded,
                                                color: Colors.white,
                                                size: 38,
                                              ),
                                              onPressed: () =>
                                                  h.skipToPrevious(),
                                            ),
                                            GestureDetector(
                                              onTap: () => playing
                                                  ? h.pause()
                                                  : h.play(),
                                              child: Container(
                                                width: 64,
                                                height: 64,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  playing
                                                      ? Icons.pause_rounded
                                                      : Icons
                                                          .play_arrow_rounded,
                                                  color: Colors.black,
                                                  size: 36,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Berikutnya',
                                              icon: const Icon(
                                                Icons.skip_next_rounded,
                                                color: Colors.white,
                                                size: 38,
                                              ),
                                              onPressed: () => h.skipToNext(),
                                            ),
                                            IconButton(
                                              tooltip: isAutoNext
                                                  ? 'Auto Next: Aktif'
                                                  : 'Auto Next: Mati',
                                              icon: Icon(
                                                Icons.repeat_rounded,
                                                color: isAutoNext
                                                    ? const Color(0xFF1DB954)
                                                    : Colors.white70,
                                                size: 24,
                                              ),
                                              onPressed: () =>
                                                  h.customAction('auto_next'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Baris bawah: tombol Lirik & Download
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  tooltip: 'Tampilkan / Sembunyikan Lirik',
                                  icon: Icon(
                                    Icons.lyrics_outlined,
                                    color: _showLyrics
                                        ? const Color(0xFF1DB954)
                                        : Colors.white70,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    setState(() => _showLyrics = !_showLyrics);
                                  },
                                ),
                                if (currentSong != null)
                                  IconButton(
                                    tooltip: 'Download ke playlist',
                                    icon: const Icon(
                                      Icons.download_for_offline_outlined,
                                      color: Colors.white70,
                                      size: 23,
                                    ),
                                    onPressed: () => pickPlaylist(
                                      context,
                                      (p) =>
                                          state.downloadInto(p, currentSong),
                                    ),
                                  ),
                              ],
                            ),

                            // Kartu Synced Lyrics
                            if (_showLyrics) ...[
                              const SizedBox(height: 8),
                              _buildLyricsCard(state, h, item),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLyricsCard(
    AppState state,
    AudioHandler h,
    MediaItem item,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Lirik',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Muat ulang lirik',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () =>
                    state.fetchSyncedLyrics(item.title, item.artist ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.isLoadingLyrics)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (state.syncedLyrics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  state.lyricErrorMessage ?? 'Lirik synced tidak tersedia.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            )
          else
            StreamBuilder<Duration>(
              stream: AudioService.position,
              builder: (context, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final activeIdx =
                    _findActiveLyricIndex(state.syncedLyrics, pos);

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.syncedLyrics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final line = state.syncedLyrics[i];
                    final isActive = i == activeIdx;
                    final isPassed = i < activeIdx;

                    return GestureDetector(
                      onTap: () => h.seek(line.time),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : (isPassed
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.62)),
                          fontSize: isActive ? 20 : 16.5,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.w600,
                          height: 1.35,
                        ),
                        child: Text(line.text),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
