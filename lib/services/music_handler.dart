import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import 'music_api.dart';

class MusicHandler extends BaseAudioHandler {
  MusicHandler(this._api) {
    _player.playbackEventStream.listen((_) => _broadcast());
    _player.playerStateStream.listen((_) => _broadcast());
  }

  final MusicApi _api;
  final AudioPlayer _player = AudioPlayer();

  Future<void> playSong(Song song) async {
    final tag = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      artUri: song.artUri,
    );
    mediaItem.add(tag);

    final source = song.isDownloaded
        ? AudioSource.file(song.localPath!, tag: tag)
        : AudioSource.uri(Uri.parse(await _api.resolveMp3(song.id)), tag: tag);

    await _player.setAudioSource(source);
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  void _broadcast() {
    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0],
      processingState: _map(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  AudioProcessingState _map(ProcessingState s) => switch (s) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };
}
