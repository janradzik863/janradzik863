import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';

class VoicesScreen extends StatelessWidget {
  const VoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteka głosów'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
        actions: [
          IconButton(
            tooltip: 'Zamilcz',
            onPressed: () => voice.stopSpeaking(),
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Wybierz głos, którym mówi agent. Wszystkie głosy pochodzą z '
            'silnika TTS zainstalowanego na Twoim urządzeniu — nic nie wychodzi '
            'na zewnątrz.',
            style: TextStyle(color: CwColors.whiteDim, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (!voice.ttsAvailable)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'Silnik mowy nie jest dostępny na tej platformie. '
                    'Android i Windows obsługują pełną bibliotekę głosów.'),
              ),
            )
          else if (voice.voices.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'Brak głosów TTS. Zainstaluj silnik mowy w ustawieniach '
                    'systemu (np. Google Synteza mowy) i wróć tutaj.'),
              ),
            )
          else
            for (final v in voice.voices)
              _VoiceTile(
                voice: v,
                active: voice.activeVoice == v.name,
                onSelect: () => voice.select(v),
                onPreview: () => voice.preview(v),
              ),
          const SizedBox(height: 20),
          const Text('TEMPO MOWY',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.whiteDim)),
          Slider(
            value: voice.rate,
            min: 0.5,
            max: 2.0,
            activeColor: CwColors.crimson,
            label: voice.rate.toStringAsFixed(1),
            onChanged: (v) => voice.setRate(v),
          ),
          const SizedBox(height: 8),
          const Text('WYSOKOŚĆ GŁOSU',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.whiteDim)),
          Slider(
            value: voice.pitch,
            min: 0.5,
            max: 2.0,
            activeColor: CwColors.crimson,
            label: voice.pitch.toStringAsFixed(1),
            onChanged: (v) => voice.setPitch(v),
          ),
        ],
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.voice,
    required this.active,
    required this.onSelect,
    required this.onPreview,
  });

  final TtsVoice voice;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: active ? CwColors.crimsonDark : CwColors.surface,
      child: ListTile(
        onTap: onSelect,
        leading: Icon(
          active ? Icons.radio_button_checked : Icons.radio_button_off,
          color: active ? CwColors.white : CwColors.whiteDim,
          size: 20,
        ),
        title: Text(
          voice.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            voice.locale,
            if (voice.isPolish) 'POLSKI',
          ].join(' • '),
          style: const TextStyle(fontSize: 11, color: CwColors.whiteDim),
        ),
        trailing: IconButton(
          tooltip: 'Odsłuchaj próbkę',
          icon: const Icon(Icons.play_circle_outline,
              color: CwColors.crimson, size: 26),
          onPressed: onPreview,
        ),
      ),
    );
  }
}
