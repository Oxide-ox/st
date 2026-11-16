import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

class AppState extends ChangeNotifier {
  AppState({required this.api, required this.handler});

  final MusicApi api;
  final MusicHandler handler;
  final _store = LibraryStore();
  final _dl = DownloadService();
  final _google = GoogleSignIn(scopes: ['email']);
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

  User? get _supabaseUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get loggedIn => _supabaseUser != null || userEmail != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    liquidGlass = _prefs.getBool('liquidGlass') ?? true;
    userEmail = _supabaseUser?.email ?? _prefs.getString('userEmail');
    playlists = await _store.load();
    if (playlists.isEmpty) {
      playlists = [Playlist(id: _newId(), name: 'Favorit')];
      await _store.save(playlists);
    }
    _listenTrackForLyrics();
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> signInGoogle() async {
    try {
      final acc = await _google.signIn();
      if (acc == null) return;
      userEmail = acc.email;
      await _prefs.setString('userEmail', acc.email);
      notifyListeners();
    } catch (e) {
      debugPrint('google sign-in error: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    await _google.signOut();
    userEmail = null;
    await _prefs.remove('userEmail');
    notifyListeners();
  }

  void setLiquidGlass(bool value) {
    liquidGlass = value;
    _prefs.setBool('liquidGlass', value);
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    searching = true;
    notifyListeners();
    try {
      results = await api.search(query.trim());
    } catch (e) {
      debugPrint('search error: $e');
      results = [];
    }
    searching = false;
    notifyListeners();
  }

  Future<void> play(Song song, {List<Song>? queue}) async {
    try {
      await handler.playSong(song, contextQueue: queue);
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
