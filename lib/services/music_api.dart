import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class MusicApi {
  static const _base = 'https://api.nexray.eu.cc';

  Future<List<Song>> search(String query) async {
    final url = Uri.parse('$_base/search/spotify?q=${Uri.encodeQueryComponent(query)}');
    final res = await http.get(url).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw Exception('search ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['status'] != true) return [];
    return (data['result'] as List)
        .take(20)
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> resolveMp3(String spotifyUrl) async {
    final targetUrl = spotifyUrl.startsWith('http')
        ? spotifyUrl
        : 'https://open.spotify.com/track/$spotifyUrl';
    final encoded = Uri.encodeComponent(targetUrl);

    final resolvers = <Future<String> Function()>[
      () => _resolveNexray(encoded),
      () => _resolveSnowping(encoded),
      () => _resolveYonz(encoded),
    ];

    final errors = <String>[];
    for (final resolve in resolvers) {
      try {
        final mp3Url = await resolve();
        if (mp3Url.startsWith('http')) {
          return mp3Url;
        }
      } catch (e) {
        errors.add(e.toString());
      }
    }

    throw Exception('Semua API gagal: ${errors.join(' | ')}');
  }

  Future<String> _resolveNexray(String encodedUrl) async {
    final url = Uri.parse('$_base/downloader/spotify?url=$encodedUrl');
    final res = await http.get(url).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('nexray ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['status'] != true) throw Exception('nexray status false');
    final link = data['result']?['url'] as String?;
    if (link == null || link.isEmpty) throw Exception('nexray empty url');
    return link;
  }

  Future<String> _resolveSnowping(String encodedUrl) async {
    final url = Uri.parse('https://api.snowping.cfd/api/downloader/spotify?url=$encodedUrl');
    final res = await http.get(url).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw Exception('snowping ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['status'] != 200 && data['status'] != true) {
      throw Exception('snowping status ${data['status']}');
    }
    final link = data['result']?['download_url'] as String?;
    if (link == null || link.isEmpty) throw Exception('snowping empty url');
    return link;
  }

  Future<String> _resolveYonz(String encodedUrl) async {
    final url = Uri.parse('https://api.yonz.cloud/download/spotify?apikey=W62R&url=$encodedUrl');
    final res = await http.get(url).timeout(const Duration(seconds: 22));
    if (res.statusCode != 200) throw Exception('yonz ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['status'] != true) throw Exception('yonz status false');
    final result = data['result'] as Map<String, dynamic>?;
    final link = (result?['downloadUrl'] ?? result?['url_audio_mp3']) as String?;
    if (link == null || link.isEmpty) throw Exception('yonz empty url');
    return link;
  }
}
