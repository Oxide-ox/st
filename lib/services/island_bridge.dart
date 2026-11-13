import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IslandBridge {
  IslandBridge(this.handler) {
    _instance = this;
  }

  static const _prefKey = 'dynamic_island_enabled';
  static const _notifChannel = MethodChannel('com.singo.tune/custom_notif');

  static IslandBridge? _instance;
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  final AudioHandler handler;

  MediaItem? _lastItem;
  bool _lastPlaying = false;
  int _lastPosMs = 0;
  int _lastSentPosMs = -2000;
  bool _enabled = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? false;
    enabledNotifier.value = _enabled;

    handler.mediaItem.listen((item) {
      _lastItem = item;
      _pushState();
    });

    handler.playbackState.listen((state) {
      _lastPlaying = state.playing;
      _lastPosMs = state.position.inMilliseconds;
      _pushState();
      if (_enabled && state.playing) {
        ensureOverlayVisible();
      }
    });

    AudioService.position.listen((pos) {
      final ms = pos.inMilliseconds;
      _lastPosMs = ms;
      if ((ms - _lastSentPosMs).abs() >= 900) {
        _lastSentPosMs = ms;
        _pushState(updateCustomNotif: false);
      }
    });

    FlutterOverlayWindow.overlayListener.listen((event) async {
      if (event is! Map) return;
      switch (event['cmd']) {
        case 'sync':
          await _pushState(updateCustomNotif: false);
          break;
        case 'toggle':
          if (_lastPlaying) {
            await handler.pause();
          } else {
            await handler.play();
          }
          break;
        case 'next':
          await handler.skipToNext();
          break;
        case 'prev':
          await handler.skipToPrevious();
          break;
        case 'shuffle':
          await handler.customAction('shuffle');
          break;
        case 'seek':
          final ms = event['ms'];
          if (ms is int) {
            await handler.seek(Duration(milliseconds: ms));
          }
          break;
        case 'off':
          await setEnabled(false);
          break;
      }
    });

    _notifChannel.setMethodCallHandler((call) async {
      if (call.method == 'onCommand') {
        switch (call.arguments) {
          case 'toggle':
            if (_lastPlaying) {
              await handler.pause();
            } else {
              await handler.play();
            }
            break;
          case 'next':
            await handler.skipToNext();
            break;
          case 'prev':
            await handler.skipToPrevious();
            break;
        }
      }
    });

    if (_enabled) {
      await ensureOverlayVisible();
    }
  }

  Future<void> _pushState({bool updateCustomNotif = true}) async {
    if (updateCustomNotif && _lastItem != null) {
      try {
        await _notifChannel.invokeMethod('show', {
          'title': _lastItem?.title ?? 'Singo Tune',
          'artist': _lastItem?.artist ?? '',
          'art': _lastItem?.artUri?.toString(),
          'playing': _lastPlaying,
        });
      } catch (_) {
        // Aman diabaikan jika channel native custom_notif belum dipasang
      }
    }

    if (!await FlutterOverlayWindow.isActive()) return;
    await FlutterOverlayWindow.shareData({
      'title': _lastItem?.title ?? 'Singo Tune',
      'artist': _lastItem?.artist ?? '',
      'art': _lastItem?.artUri?.toString(),
      'playing': _lastPlaying,
      'posMs': _lastPosMs,
      'durMs': _lastItem?.duration?.inMilliseconds ?? 0,
    });
  }

  Future<void> ensureOverlayVisible() async {
    if (!_enabled) return;
    if (!await FlutterOverlayWindow.isPermissionGranted()) return;
    if (await FlutterOverlayWindow.isActive()) return;
    await _show();
  }

  Future<void> _show() async {
    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'Singo Tune',
        overlayContent: _lastItem?.title ?? 'Dynamic Island aktif',
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.topCenter,
        width: 250,
        height: 54,
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _pushState(updateCustomNotif: false);
    } catch (_) {
      // Mencegah crash ForegroundServiceStartNotAllowedException di Android 12 saat app di background
    }
  }

  static Future<bool> setEnabled(bool enabled) async {
    final bridge = _instance;
    if (bridge == null) return false;

    final prefs = await SharedPreferences.getInstance();

    if (!enabled) {
      bridge._enabled = false;
      enabledNotifier.value = false;
      await prefs.setBool(_prefKey, false);
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
      return false;
    }

    var granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      granted = (await FlutterOverlayWindow.requestPermission()) ?? false;
      if (!granted) {
        bridge._enabled = false;
        enabledNotifier.value = false;
        await prefs.setBool(_prefKey, false);
        return false;
      }
    }

    bridge._enabled = true;
    enabledNotifier.value = true;
    await prefs.setBool(_prefKey, true);
    if (!await FlutterOverlayWindow.isActive()) {
      await bridge._show();
    }
    return true;
  }

  static Future<bool> toggleFromUi() => setEnabled(!enabledNotifier.value);
}
