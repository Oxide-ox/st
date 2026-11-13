import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import 'music_api.dart';

class MusicHandler extends BaseAudioHandler {
  MusicHandler(this._api) {
    _player.playbackEventStream.listen((_) => _broadcast());
    _player.playerStateStream.listen((state) {
      _broadcast();
      if (state.processingState == ProcessingState.completed && _songs.length > 1) {
        skipToNext();
      }
    });
    _player.durationStream.listen((dur) {
      final current = mediaItem.value;
      if (dur != null && current != null && current.duration != dur) {
        mediaItem.add(current.copyWith(duration: dur));
      }
    });
  }

  final MusicApi _api;
  final AudioPlayer _player = AudioPlayer();
  final List<Song> _songs = [];
  int _index = -1;
  bool _shuffle = false;

  Future<void> playSong(Song song) async {
    final existingIdx = _songs.indexWhere((s) => s.id == song.id);
    if (existingIdx >= 0) {
      _songs[existingIdx] = song;
      _index = existingIdx;
    } else {
      _songs.add(song);
      _index = _songs.length - 1;
    }

    final tag = _toMediaItem(song);
    queue.add(_songs.map(_toMediaItem).toList());
    mediaItem.add(tag);

    final source = song.isDownloaded
        ? AudioSource.file(song.localPath!, tag: tag)
        : AudioSource.uri(Uri.parse(await _api.resolveMp3(song.id)), tag: tag);

    final dur = await _player.setAudioSource(source);
    if (dur != null) {
      mediaItem.add(tag.copyWith(duration: dur));
    }
    await _player.play();
  }

  MediaItem _toMediaItem(Song song) => MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        artUri: song.artUri,
      );

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_songs.isEmpty) return;
    if (_shuffle && _songs.length > 1) {
      final rnd = Random();
      int nextIdx = _index;
      while (nextIdx == _index) {
        nextIdx = rnd.nextInt(_songs.length);
      }
      await playSong(_songs[nextIdx]);
      return;
    }
    final nextIdx = (_index + 1) % _songs.length;
    await playSong(_songs[nextIdx]);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_songs.isEmpty) return;
    final prevIdx = (_index - 1 + _songs.length) % _songs.length;
    await playSong(_songs[prevIdx]);
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'shuffle') {
      _shuffle = !_shuffle;
      await _player.setShuffleModeEnabled(_shuffle);
      _broadcast();
    }
    return super.customAction(name, extras);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  void _broadcast() {
    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _map(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      shuffleMode: _shuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
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
