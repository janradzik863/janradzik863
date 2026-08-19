import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/radio_service.dart';

/// Punkt 13: Wspólne Radio Społecznościowe.
class RadioScreen extends StatelessWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final radio = context.watch<RadioService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radio Wilków'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: Column(
        children: [
          // Aktualnie grany utwór
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: CwColors.surface,
            child: Column(
              children: [
                const Icon(Icons.radio, size: 48, color: CwColors.crimson),
                const SizedBox(height: 8),
                Text(
                  radio.currentTrack?.title ?? 'Brak utworu',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: CwColors.white),
                  textAlign: TextAlign.center,
                ),
                if (radio.currentTrack?.artist.isNotEmpty ?? false)
                  Text(
                    radio.currentTrack!.artist,
                    style: const TextStyle(
                        fontSize: 13, color: CwColors.whiteDim),
                  ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: radio.previous,
                      icon: const Icon(Icons.skip_previous,
                          color: CwColors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: CwColors.crimson,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: radio.playing ? radio.pause : radio.play,
                        icon: Icon(
                          radio.playing ? Icons.pause : Icons.play_arrow,
                          color: CwColors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: radio.next,
                      icon: const Icon(Icons.skip_next,
                          color: CwColors.white, size: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  radio.playing ? '▶ Na żywo' : '⏸ Pauza',
                  style: TextStyle(
                    fontSize: 12,
                    color: radio.playing ? CwColors.online : CwColors.whiteDim,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Kolejka
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Text('KOLEJKA',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: CwColors.whiteDim)),
                const Spacer(),
                TextButton(
                  onPressed: radio.clearQueue,
                  child: const Text('Wyczyść',
                      style: TextStyle(fontSize: 12, color: CwColors.crimson)),
                ),
              ],
            ),
          ),
          Expanded(
            child: radio.queue.isEmpty
                ? const Center(
                    child: Text('Kolejka jest pusta.',
                        style: TextStyle(color: CwColors.whiteDim)),
                  )
                : ListView.builder(
                    itemCount: radio.queue.length,
                    itemBuilder: (_, i) {
                      final t = radio.queue[i];
                      final isCurrent = i == radio.currentIndex;
                      return ListTile(
                        leading: Icon(
                          isCurrent
                              ? Icons.play_circle_filled
                              : Icons.music_note_outlined,
                          color: isCurrent ? CwColors.crimson : CwColors.whiteDim,
                        ),
                        title: Text(t.title,
                            style: TextStyle(
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w400,
                            )),
                        subtitle: Text(t.artist.isEmpty ? 'Nieznany' : t.artist,
                            style: const TextStyle(
                                fontSize: 12, color: CwColors.whiteDim)),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          // Biblioteka utworów
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Text('BIBLIOTEKA',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: CwColors.whiteDim)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _addTrack(context, radio),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Dodaj utwór'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: radio.tracks.isEmpty
                ? const Center(
                    child: Text('Brak utworów.',
                        style: TextStyle(color: CwColors.whiteDim)),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: radio.tracks.length,
                    itemBuilder: (_, i) {
                      final t = radio.tracks[i];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => radio.enqueue(t),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.queue_music,
                                    color: CwColors.crimson),
                                const SizedBox(height: 6),
                                Text(t.title,
                                    style: const TextStyle(fontSize: 13)),
                                Text(t.artist.isEmpty ? '' : t.artist,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: CwColors.whiteDim)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _addTrack(BuildContext context, RadioService radio) {
    final titleCtrl = TextEditingController();
    final artistCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CwColors.surface,
        title: const Text('Dodaj utwór'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(hintText: 'Tytuł'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: artistCtrl,
              decoration: const InputDecoration(hintText: 'Artysta'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              radio.addTrack(
                title: titleCtrl.text.trim(),
                filePath: '/local/${titleCtrl.text.trim()}.mp3',
                artist: artistCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }
}
