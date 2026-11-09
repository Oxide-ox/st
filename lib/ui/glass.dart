import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding,
    this.margin,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final glass = context.select<AppState, bool>((s) => s.liquidGlass);
    final r = BorderRadius.circular(radius);

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        color: glass ? null : const Color(0xFF1C1C1E),
        gradient: glass
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.24),
                  Colors.white.withOpacity(0.05),
                ],
              )
            : null,
        border: Border.all(
          color: Colors.white.withOpacity(glass ? 0.28 : 0.06),
        ),
        boxShadow: glass
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: child,
    );

    final body = glass
        ? ClipRRect(
            borderRadius: r,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: content,
            ),
          )
        : ClipRRect(borderRadius: r, child: content);

    return Padding(padding: margin ?? EdgeInsets.zero, child: body);
  }
}

class AlbumBackdrop extends StatelessWidget {
  const AlbumBackdrop({super.key, this.art});

  final Uri? art;

  @override
  Widget build(BuildContext context) {
    ImageProvider? img;
    if (art != null) {
      img = art!.scheme == 'file'
          ? FileImage(File(art!.toFilePath()))
          : NetworkImage(art!.toString());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E1065), Color(0xFF0B1F4A), Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (img != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Image(image: img, fit: BoxFit.cover),
          ),
        Container(color: Colors.black.withOpacity(0.45)),
      ],
    );
  }
}

class ArtThumb extends StatelessWidget {
  const ArtThumb({super.key, required this.uri, this.size = 48});

  final Uri? uri;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (uri == null) {
      child = const Icon(Icons.music_note);
    } else if (uri!.scheme == 'file') {
      child = Image.file(File(uri!.toFilePath()), fit: BoxFit.cover, errorBuilder: _err);
    } else {
      child = Image.network(uri.toString(), fit: BoxFit.cover, errorBuilder: _err);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _err(BuildContext context, Object error, StackTrace? stack) =>
      const Icon(Icons.music_note);
}
