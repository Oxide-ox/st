import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'glass.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final h = s.handler;
    return Stack(
      children: [
        Positioned.fill(
          child: StreamBuilder<MediaItem?>(
            stream: h.mediaItem,
            builder: (_, snap) => AlbumBackdrop(art: snap.data?.artUri),
          ),
        ),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Pengaturan',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GlassBox(
                child: SwitchListTile(
                  title: const Text('Liquid Glass'),
                  subtitle: const Text('Matikan untuk tampilan solid'),
                  value: s.liquidGlass,
                  onChanged: s.setLiquidGlass,
                ),
              ),
              const SizedBox(height: 12),
              GlassBox(
                child: ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: Text(s.userEmail ?? 'Belum login'),
                  trailing: TextButton(onPressed: s.signOut, child: const Text('Keluar')),
                ),
              ),
              const SizedBox(height: 12),
              const GlassBox(
                child: ListTile(
                  leading: Icon(Icons.notifications_active),
                  title: Text('Background & notifikasi'),
                  subtitle: Text(
                    'Musik tetap jalan saat app ditutup atau dihapus dari recent',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
