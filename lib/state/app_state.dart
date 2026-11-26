import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/download_service.dart';
import '../services/library_store.dart';
import '../services/music_api.dart';
import '../services/music_handler.dart';

class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

class SpotifyShelf {
  const SpotifyShelf({
    required this.title,
    this.subtitle,
    required this.songs,
  });

  final String title;
  final String? subtitle;
  final List<Song> songs;
}

class AppState extends ChangeNotifier {
  AppState({required this.api, required this.handler});

  final MusicApi api;
  final MusicHandler handler;
  final _store = LibraryStore();
  final _dl = DownloadService();
  late SharedPreferences _prefs;

  bool liquidGlass = true;
  String? userEmail;
  List<Playlist> playlists = [];
  List<Song> results = [];
  bool searching = false;
  String? downloadingId;
  double downloadProgress = 0;

  bool isLoadingLyrics = false;
  List<LyricLine> syncedLyrics = [];
  String? lyricErrorMessage;
  String? _lastLyricKey;

  Map<String, int> _artistScores = {};
  List<String> _searchHistory = [];
  List<Song> recentSongs = [];
  List<SpotifyShelf> spotifyShelves = [];
  String dashboardFilter = 'Semua';
  bool loadingRecommendations = false;

  User? get _supabaseUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get loggedIn => _supabaseUser != null || userEmail != null;

  List<Song> get quickGridSongs {
    final map = <String, Song>{};
    for (final s in recentSongs) {
      map[s.id] = s;
    }
    for (final shelf in spotifyShelves) {
      for (final s in shelf.songs) {
        map.putIfAbsent(s.id, () => s);
      }
    }
    return map.values.take(6).toList();
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    liquidGlass = _prefs.getBool('liquidGlass') ?? true;
    userEmail = _supabaseUser?.email ?? _prefs.getString('userEmail');
    playlists = await _store.load();
    if (playlists.isEmpty) {
      playlists = [Playlist(id: _newId(), name: 'Favorit')];
      await _store.save(playlists);
    }
    await _loadTasteProfile();
    _listenTrackForLyrics();
    notifyListeners();
    loadRecommendations();
  }

  void _listenTrackForLyrics() {
    handler.mediaItem.listen((item) {
      if (item == null) return;
      final key = '${item.title}|${item.artist ?? ''}';
      if (_lastLyricKey == key) return;
      _lastLyricKey = key;
      fetchSyncedLyrics(item.title, item.artist ?? '');
    });
  }

  void refreshAuth() {
    final email = _supabaseUser?.email;
    if (email != null) {
      userEmail = email;
      _prefs.setString('userEmail', email);
    }
    _loadTasteProfile().then((_) => loadRecommendations(forceRefresh: true));
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    userEmail = null;
    await _prefs.remove('userEmail');
    notifyListeners();
  }

  void setLiquidGlass(bool value) {
    liquidGlass = value;
    _prefs.setBool('liquidGlass', value);
    notifyListeners();
  }

  void setDashboardFilter(String filter) {
    dashboardFilter = filter;
    notifyListeners();
  }

  Future<void> _loadTasteProfile() async {
    try {
      final rawScores = _prefs.getString('taste_scores');
      if (rawScores != null) {
        final decoded = json.decode(rawScores) as Map<String, dynamic>;
        _artistScores = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    } catch (_) {}

    _searchHistory = _prefs.getStringList('taste_searches') ?? [];

    try {
      final rawRecent = _prefs.getString('taste_recent');
      if (rawRecent != null) {
        final list = json.decode(rawRecent) as List;
        recentSongs = list
            .map((e) => _songFromCache(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    final uid = _supabaseUser?.id;
    if (uid != null) {
      try {
        final row = await Supabase.instance.client
            .from('users')
            .select('taste_profile')
            .eq('id', uid)
            .maybeSingle();
        final remote = row?['taste_profile'];
        if (remote is Map && remote['scores'] is Map) {
          final scores = remote['scores'] as Map<String, dynamic>;
          scores.forEach((k, v) {
            final localVal = _artistScores[k] ?? 0;
            final remoteVal = (v as num).toInt();
            if (remoteVal > localVal) _artistScores[k] = remoteVal;
          });
        }
      } catch (_) {}
    }
  }

  Map<String, dynamic> _songToCache(Song s) => {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'album': s.album,
        'artUri': s.artUri?.toString(),
        'localPath': s.localPath,
      };

  Song _songFromCache(Map<String, dynamic> m) => Song(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        artist: (m['artist'] ?? '').toString(),
        album: m['album']?.toString(),
        artUri: m['artUri'] != null ? Uri.tryParse(m['artUri'].toString()) : null,
        localPath: m['localPath']?.toString(),
      );

  Future<void> _recordInteraction({
    String? artist,
    String? query,
    Song? playedSong,
    int weight = 1,
  }) async {
    if (artist != null && artist.trim().isNotEmpty) {
      final mainArtist = artist.split(',').first.trim();
      _artistScores[mainArtist] = (_artistScores[mainArtist] ?? 0) + weight;
    }

    if (query != null && query.trim().length >= 3) {
      final q = query.trim();
      _searchHistory.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
      _searchHistory.insert(0, q);
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }
    }

    if (playedSong != null) {
      recentSongs.removeWhere((s) => s.id == playedSong.id);
      recentSongs.insert(0, playedSong);
      if (recentSongs.length > 15) {
        recentSongs = recentSongs.sublist(0, 15);
      }
    }

    await _prefs.setString('taste_scores', json.encode(_artistScores));
    await _prefs.setStringList('taste_searches', _searchHistory);
    await _prefs.setString(
      'taste_recent',
      json.encode(recentSongs.map(_songToCache).toList()),
    );

    final uid = _supabaseUser?.id;
    if (uid != null) {
      Supabase.instance.client.from('users').update({
        'taste_profile': {
          'scores': _artistScores,
          'searches': _searchHistory,
        },
      }).eq('id', uid).catchError((_) {});
    }
  }

  Future<void> loadRecommendations({bool forceRefresh = false}) async {
    if (loadingRecommendations) return;
    if (spotifyShelves.isNotEmpty && !forceRefresh) return;

    loadingRecommendations = true;
    notifyListeners();

    try {
      final sortedArtists = _artistScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final shelves = <SpotifyShelf>[];
      final mixPool = <Song>[];

      if (sortedArtists.isNotEmpty) {
        for (final entry in sortedArtists.take(3)) {
          final artistName = entry.key;
          final tracks = await api.search(artistName);
          if (tracks.isEmpty) continue;

          mixPool.addAll(tracks.take(6));
          shelves.add(
            SpotifyShelf(
              title: shelves.isEmpty
                  ? 'Lebih banyak dari $artistName'
                  : 'Karena kamu mendengarkan $artistName',
              subtitle: 'Artis favoritmu',
              songs: tracks.take(12).toList(),
            ),
          );
        }
      } else if (_searchHistory.isNotEmpty) {
        final q = _searchHistory.first;
        final tracks = await api.search(q);
        mixPool.addAll(tracks);
        if (tracks.isNotEmpty) {
          shelves.add(
            SpotifyShelf(
              title: 'Berdasarkan pencarian "$q"',
              songs: tracks.take(12).toList(),
            ),
          );
        }
      } else {
        final hits = await api.search('Top Hits Indonesia');
        final viral = await api.search('Lagu Viral TikTok Indonesia');
        mixPool.addAll(hits.take(8));
        if (hits.isNotEmpty) {
          shelves.add(
            SpotifyShelf(title: 'Terpopuler Hari Ini', songs: hits.take(12).toList()),
          );
        }
        if (viral.isNotEmpty) {
          shelves.add(
            SpotifyShelf(title: 'Sedang Viral', songs: viral.take(12).toList()),
          );
        }
      }

      if (mixPool.isNotEmpty) {
        final uniqueMix = <String, Song>{};
        for (final s in mixPool) {
          uniqueMix[s.id] = s;
        }
        final mixList = uniqueMix.values.toList()..shuffle();
        shelves.insert(
          0,
          SpotifyShelf(
            title: 'Daily Mix Untukmu',
            subtitle: sortedArtists.isNotEmpty
                ? sortedArtists.take(3).map((e) => e.key).join(', ')
                : 'Pilihan segar untukmu',
            songs: mixList.take(15).toList(),
          ),
        );
      }

      spotifyShelves = shelves;
    } catch (e) {
      debugPrint('spotify shelves error: $e');
    }

    loadingRecommendations = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    searching = true;
    notifyListeners();
    try {
      results = await api.search(query.trim());
      await _recordInteraction(query: query, weight: 2);
    } catch (e) {
      debugPrint('search error: $e');
      results = [];
    }
    searching = false;
    notifyListeners();
  }
   
    void clearResults() {
    results = [];
    notifyListeners();
  }

  Future<void> play(Song song, {List<Song>? queue}) async {
    try {
      await handler.playSong(song, contextQueue: queue);
      await _recordInteraction(artist: song.artist, playedSong: song, weight: 3);
      notifyListeners();
    } catch (e) {
      debugPrint('play error: $e');
    }
  }

  Future<void> fetchSyncedLyrics(String title, String artist) async {
    isLoadingLyrics = true;
    lyricErrorMessage = null;
    syncedLyrics = [];
    notifyListeners();

    try {
      final queryTitle = Uri.encodeComponent(title);
      final queryArtist = Uri.encodeComponent(artist);

      final url = Uri.parse(
        "https://lrclib.net/api/get?track_name=$queryTitle&artist_name=$queryArtist",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String? rawSyncedLyrics = data['syncedLyrics'];

        if (rawSyncedLyrics != null && rawSyncedLyrics.isNotEmpty) {
          syncedLyrics = _parseLrc(rawSyncedLyrics);
        } else {
          lyricErrorMessage = "Lirik synced tidak tersedia.";
        }
      } else {
        final searchUrl = Uri.parse(
          "https://lrclib.net/api/search?q=$queryTitle $queryArtist",
        );
        final searchRes = await http.get(searchUrl);
        if (searchRes.statusCode == 200) {
          final List searchData = json.decode(searchRes.body);
          if (searchData.isNotEmpty && searchData[0]['syncedLyrics'] != null) {
            syncedLyrics = _parseLrc(searchData[0]['syncedLyrics']);
          } else {
            lyricErrorMessage = "Lirik tidak ditemukan.";
          }
        } else {
          lyricErrorMessage = "Lirik tidak ditemukan.";
        }
      }
    } catch (e) {
      lyricErrorMessage = "Gagal memuat lirik.";
      debugPrint("Error fetching synced lyrics: $e");
    }

    isLoadingLyrics = false;
    notifyListeners();
  }

  List<LyricLine> _parseLrc(String lrcString) {
    final lines = lrcString.split('\n');
    final List<LyricLine> parsedList = [];
    final regExp = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)');

    for (var line in lines) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();

        if (text.isNotEmpty) {
          final duration = Duration(
            minutes: minutes,
            seconds: seconds.truncate(),
            milliseconds: ((seconds - seconds.truncate()) * 1000).round(),
          );
          parsedList.add(LyricLine(time: duration, text: text));
        }
      }
    }

    parsedList.sort((a, b) => a.time.compareTo(b.time));
    return parsedList;
  }

  Future<void> createPlaylist(String name) async {
    playlists.add(Playlist(id: _newId(), name: name));
    await _persist();
  }

  Future<void> deletePlaylist(Playlist p) async {
    playlists.removeWhere((x) => x.id == p.id);
    await _persist();
  }

  Future<void> addSong(Playlist p, Song song) async {
    if (p.songs.any((s) => s.id == song.id)) return;
    p.songs.add(song);
    await _recordInteraction(artist: song.artist, weight: 5);
    await _persist();
  }

  Future<void> removeSong(Playlist p, Song song) async {
    p.songs.removeWhere((s) => s.id == song.id);
    await _persist();
  }

  Future<void> downloadInto(Playlist p, Song song) async {
    if (downloadingId != null) return;
    try {
      final ready = _findDownloaded(song.id) ?? await _fetchAndStore(song);
      p.songs.removeWhere((s) => s.id == song.id);
      p.songs.add(ready);
      await _recordInteraction(artist: song.artist, weight: 5);
      await _persist();
    } catch (e) {
      debugPrint('download error: $e');
    } finally {
      downloadingId = null;
      downloadProgress = 0;
      notifyListeners();
    }
  }

  Future<Song> _fetchAndStore(Song song) async {
    downloadingId = song.id;
    downloadProgress = 0;
    notifyListeners();
    final mp3 = await api.resolveMp3(song.id);
    return _dl.download(song, mp3, (v) {
      downloadProgress = v;
      notifyListeners();
    });
  }

  Song? _findDownloaded(String id) {
    for (final p in playlists) {
      for (final s in p.songs) {
        if (s.id == id && s.isDownloaded) return s;
      }
    }
    return null;
  }

  Future<void> _persist() async {
    await _store.save(playlists);
    notifyListeners();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
