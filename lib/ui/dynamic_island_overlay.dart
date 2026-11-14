import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

void runDynamicIslandOverlay() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DynamicIslandOverlayApp(),
    ),
  );
}

class DynamicIslandOverlayApp extends StatefulWidget {
  const DynamicIslandOverlayApp({super.key});

  @override
  State<DynamicIslandOverlayApp> createState() => _DynamicIslandOverlayAppState();
}

class _DynamicIslandOverlayAppState extends State<DynamicIslandOverlayApp> {
  String _title = 'Singo Tune';
  String _artist = 'Siap memutar';
  String? _art;
  bool _playing = false;
  bool _expanded = false;
  int _posMs = 0;
  int _durMs = 0;
  int? _draggingMs;

  StreamSubscription<dynamic>? _sub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && mounted) {
        setState(() {
          _title = (event['title'] as String?) ?? _title;
          _artist = (event['artist'] as String?) ?? _artist;
          _art = event['art'] as String?;
          _playing = (event['playing'] as bool?) ?? _playing;
          if (event['posMs'] is int) _posMs = event['posMs'] as int;
          if (event['durMs'] is int) _durMs = event['durMs'] as int;
        });
      }
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_playing || _draggingMs != null || _durMs <= 0) return;
      setState(() {
        _posMs = (_posMs + 1000).clamp(0, _durMs);
      });
    });

    FlutterOverlayWindow.shareData({'cmd': 'sync'});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _setExpanded(bool expand) async {
    if (expand) {
      await FlutterOverlayWindow.resizeOverlay(336, 178, true);
      if (mounted) setState(() => _expanded = true);
    } else {
      setState(() => _expanded = false);
      await FlutterOverlayWindow.resizeOverlay(250, 54, true);
    }
  }

  void _sendCmd(String cmd, [Map<String, dynamic>? extra]) {
    FlutterOverlayWindow.shareData({'cmd': cmd, ...?extra});
  }

  String _fmt(int ms) {
    final totalSec = (ms ~/ 1000).clamp(0, 359999);
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildArtImage() {
    final raw = _art;
    if (raw == null || raw.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF2E1065),
        child: Icon(Icons.music_note_rounded, color: Colors.white70, size: 22),
      );
    }
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'file') {
      return Image.file(
        File(uri.toFilePath()),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Color(0xFF2E1065),
          child: Icon(Icons.music_note_rounded, color: Colors.white70, size: 22),
        ),
      );
    }
    return Image.network(
      raw,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFF2E1065),
        child: Icon(Icons.music_note_rounded, color: Colors.white70, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              gradient: const LinearGradient(
                colors: [Color(0xFF26124A), Color(0xFF0A0A0C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_art != null && _art!.isNotEmpty) _buildArtImage(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (_expanded && constraints.maxHeight >= 135) {
                      return _buildExpandedCard();
                    }
                    return _buildCompactPill();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactPill() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setExpanded(true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(width: 34, height: 34, child: _buildArtImage()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () => _sendCmd('toggle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCard() {
    final maxMs = _durMs > 0 ? _durMs.toDouble() : 1.0;
    final curMs = (_draggingMs ?? _posMs).toDouble().clamp(0.0, maxMs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Singo Tune • Ponsel ini',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _setExpanded(false),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _sendCmd('off'),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _artist.isEmpty ? 'Singo Tune' : _artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 22,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
                thumbColor: Colors.white,
              ),
              child: Slider(
                min: 0.0,
                max: maxMs,
                value: curMs,
                onChanged: _durMs <= 0
                    ? null
                    : (v) => setState(() => _draggingMs = v.round()),
                onChangeEnd: _durMs <= 0
                    ? null
                    : (v) {
                        final target = v.round();
                        setState(() {
                          _posMs = target;
                          _draggingMs = null;
                        });
                        _sendCmd('seek', {'ms': target});
                      },
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(curMs.round()),
                style: const TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
              Text(
                _fmt(_durMs),
                style: const TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
            ],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                  onPressed: () => _sendCmd('shuffle'),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26),
                  onPressed: () => _sendCmd('prev'),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => _sendCmd('toggle'),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 26),
                  onPressed: () => _sendCmd('next'),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white70, size: 20),
                  onPressed: () => _sendCmd('off'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
