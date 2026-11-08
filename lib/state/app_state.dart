import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/download_service.dart';
import '../services/library_store.dart';
import '../services/music_api.dart';
import '../services/music_handler.dart';

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

  bool get loggedIn => userEmail != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    liquidGlass = _prefs.getBool('liquidGlass') ?? true;
    userEmail = _prefs.getString('userEmail');
    playlists = await _store.load();
    if (playlists.isEmpty) {
      playlists = [Playlist(id: _newId(), name: 'Favorit')];
      await _store.save(playlists);
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

  Future<void> play(Song song) async {
    try {
      await handler.playSong(song);
    } catch (e) {
      debugPrint('play error: $e');
    }
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
