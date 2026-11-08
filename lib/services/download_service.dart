import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<Song> download(
    Song song,
    String mp3Url,
    void Function(double) onProgress,
  ) async {
    final root = await getApplicationDocumentsDirectory();
    final name = song.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');

    final audioDir = Directory('${root.path}/audio')..createSync(recursive: true);
    final thumbDir = Directory('${root.path}/thumbs')..createSync(recursive: true);

    final audioPath = '${audioDir.path}/$name.mp3';
    final thumbPath = '${thumbDir.path}/$name.jpg';

    await _dio.download(
      mp3Url,
      audioPath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );

    String? savedThumb;
    if (song.thumbnail.isNotEmpty) {
      try {
        await _dio.download(song.thumbnail, thumbPath);
        savedThumb = thumbPath;
      } catch (_) {}
    }

    return song.copyWith(localPath: audioPath, localThumb: savedThumb);
  }
}
