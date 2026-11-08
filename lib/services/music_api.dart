import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class MusicApi {
  static const _base = 'https://api.nexray.eu.cc';

  Future<List<Song>> search(String query) async {
    final url = Uri.parse('$_base/search/spotify?q=${Uri.encodeQueryComponent(query)}');
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception('search ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['status'] != true) return [];
    return (data['result'] as List)
        .take(20)
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> resolveMp3(String spotifyUrl) async {
    final url = Uri.parse(
      '$_base/downloader/spotify?url=${Uri.encodeComponent(spotifyUrl)}',
    );
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception('resolve ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['status'] != true) throw Exception('resolve failed');
    return data['result']['url'] as String;
  }
}
