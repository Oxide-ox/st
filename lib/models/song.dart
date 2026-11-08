import 'dart:io';

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.thumbnail,
    this.localPath,
    this.localThumb,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String thumbnail;
  final String? localPath;
  final String? localThumb;

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['url'] as String,
        title: (j['title'] ?? 'Unknown') as String,
        artist: (j['artist'] ?? 'Unknown') as String,
        album: (j['album'] ?? 'Unknown Album') as String,
        thumbnail: (j['thumbnail'] ?? '') as String,
        localPath: j['localPath'] as String?,
        localThumb: j['localThumb'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'url': id,
        'title': title,
        'artist': artist,
        'album': album,
        'thumbnail': thumbnail,
        'localPath': localPath,
        'localThumb': localThumb,
      };

  Song copyWith({String? localPath, String? localThumb}) => Song(
        id: id,
        title: title,
        artist: artist,
        album: album,
        thumbnail: thumbnail,
        localPath: localPath ?? this.localPath,
        localThumb: localThumb ?? this.localThumb,
      );

  bool get isDownloaded => localPath != null && File(localPath!).existsSync();

  Uri? get artUri {
    if (localThumb != null && File(localThumb!).existsSync()) {
      return Uri.file(localThumb!);
    }
    return thumbnail.isEmpty ? null : Uri.parse(thumbnail);
  }
}
