import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'glass.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AlbumBackdrop(),
          Center(
            child: GlassBox(
              radius: 28,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Glass Music',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.read<AppState>().signInGoogle(),
                    icon: const Icon(Icons.login),
                    label: const Text('Login dengan Google'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
