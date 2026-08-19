import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/voice_service.dart';
import '../../state/app_state.dart';

/// Biblioteka głosów AI (#3): odsłuch i przełączanie.
class VoiceLibraryScreen extends StatelessWidget {
  const VoiceLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final voices = VoiceService.library;
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteka głosów')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: voices.length,
        itemBuilder: (c, i) {
          final v = voices[i];
          final selected = state.voiceId == v.id;
          return Card(
            color: selected ? AppColors.surface : AppColors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: selected
                  ? const BorderSide(color: AppColors.red, width: 1.5)
                  : BorderSide.none,
            ),
            child: ListTile(
              leading: Icon(
                Icons.record_voice_over,
                color: selected ? AppColors.red : AppColors.white,
              ),
              title: Text(v.name,
                  style: const TextStyle(color: AppColors.white)),
              subtitle: Text(v.description,
                  style: const TextStyle(color: Colors.grey)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline,
                        color: AppColors.white),
                    tooltip: 'Odsłuchaj',
                    onPressed: () => VoiceService().preview(v.id),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppColors.red),
                ],
              ),
              onTap: () => state.setVoice(v.id),
            ),
          );
        },
      ),
    );
  }
}
