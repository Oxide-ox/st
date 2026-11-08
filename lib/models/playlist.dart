import 'song.dart';

class Playlist {
  Playlist({required this.id, required this.name, List<Song>? songs})
      : songs = songs ?? <Song>[];

  final String id;
  String name;
  final List<Song> songs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songs': songs.map((s) => s.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String,
        songs: (j['songs'] as List)
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
