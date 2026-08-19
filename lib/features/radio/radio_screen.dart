import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/radio/radio_service.dart';

/// Wspólne radio społecznościowe (#13).
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  @override
  Widget build(BuildContext context) {
    final radio = context.watch<RadioService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radio społecznościowe'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.headphones, size: 16, color: AppColors.red),
                  const SizedBox(width: 4),
                  Text('${radio.listeners}',
                      style: const TextStyle(color: AppColors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _NowPlaying(radio: radio),
          const Divider(height: 1, color: AppColors.surface),
          _Controls(radio: radio),
          const Divider(height: 1, color: AppColors.surface),
          Expanded(
            child: _Queue(radio: radio),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.red,
        onPressed: () => _addTrack(context, radio),
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  void _addTrack(BuildContext context, RadioService radio) {
    final titleCtl = TextEditingController();
    final artistCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Dodaj do kolejki',
            style: TextStyle(color: AppColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(labelText: 'Tytuł'),
            ),
            TextField(
              controller: artistCtl,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(labelText: 'Wykonawca'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () {
              radio.addTrack(Track(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: titleCtl.text.trim(),
                artist: artistCtl.text.trim(),
                durationMs: 180000,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  final RadioService radio;
  const _NowPlaying({required this.radio});

  @override
  Widget build(BuildContext context) {
    final t = radio.current;
    final pos = radio.syncedPositionMs;
    final dur = t?.durationMs ?? 0;
    final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.graphic_eq, color: AppColors.red, size: 48),
          const SizedBox(height: 12),
          Text(t?.title ?? '—',
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(t?.artist ?? '',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            color: AppColors.red,
            backgroundColor: AppColors.surface,
          ),
          const SizedBox(height: 8),
          Text(
            '${_fmt(pos)} / ${_fmt(dur)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _fmt(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }
}

class _Controls extends StatelessWidget {
  final RadioService radio;
  const _Controls({required this.radio});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous,
                color: AppColors.white, size: 32),
            onPressed: radio.prev,
          ),
          IconButton(
            icon: Icon(
              radio.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: AppColors.red,
              size: 64,
            ),
            onPressed: radio.isPlaying ? radio.pause : radio.play,
          ),
          IconButton(
            icon: const Icon(Icons.skip_next,
                color: AppColors.white, size: 32),
            onPressed: radio.next,
          ),
        ],
      ),
    );
  }
}

class _Queue extends StatelessWidget {
  final RadioService radio;
  const _Queue({required this.radio});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: radio.queue.length,
      itemBuilder: (c, i) {
        final t = radio.queue[i];
        final isCurrent = t.id == radio.current?.id;
        return ListTile(
          leading: Icon(
            isCurrent ? Icons.graphic_eq : Icons.music_note,
            color: isCurrent ? AppColors.red : Colors.grey,
          ),
          title: Text(t.title,
              style: TextStyle(
                color: isCurrent ? AppColors.red : AppColors.white,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              )),
          subtitle: Text(t.artist,
              style: const TextStyle(color: Colors.grey)),
          onTap: () {
            radio.next();
          },
        );
      },
    );
  }
}
