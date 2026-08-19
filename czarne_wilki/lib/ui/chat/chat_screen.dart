import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../engine/engine_manager.dart';
import '../../services/app_services.dart';
import '../models/models_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<ChatController>().openConversation());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final engines = context.watch<EngineManager>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Czat', style: TextStyle(fontSize: 18)),
            Text(
              engines.activeModel?.displayName ?? 'wybierz model',
              style: const TextStyle(fontSize: 11, color: CwColors.whiteDim),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nowa rozmowa',
            onPressed: () => chat.newConversation(),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'Modele',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ModelsScreen()),
            ),
            icon: const Icon(Icons.memory_outlined),
          ),
          IconButton(
            tooltip: 'Przestań czytać',
            onPressed: () => context.read<VoiceController>().stopSpeaking(),
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: Column(
        children: [
          if (chat.error != null)
            _ErrorBar(message: chat.error!, onClose: chat.clearError),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              itemCount:
                  chat.messages.length + (chat.partial.isNotEmpty ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= chat.messages.length) {
                  return _Bubble(
                    text: chat.partial,
                    role: 'assistant',
                    pending: true,
                  );
                }
                final m = chat.messages[i];
                return _Bubble(
                  text: m.content,
                  role: m.role.name,
                  attachmentPath: m.attachmentPath,
                  modelName: m.modelName,
                  onSpeak: () =>
                      context.read<VoiceController>().speak(m.content),
                );
              },
            ),
          ),
          if (chat.busy) const _BusyRow(),
          _InputBar(
            controller: _input,
            chat: chat,
          ),
        ],
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: CwColors.crimsonDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: CwColors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: CwColors.white, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 16, color: CwColors.white),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.role,
    this.pending = false,
    this.attachmentPath,
    this.modelName,
    this.onSpeak,
  });

  final String text;
  final String role;
  final bool pending;
  final String? attachmentPath;
  final String? modelName;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? CwColors.crimsonDark : CwColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: isUser ? null : Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachmentPath != null && File(attachmentPath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(attachmentPath!), width: 280),
              ),
            if (text.isNotEmpty)
              Text(
                text + (pending ? ' ▍' : ''),
                style: const TextStyle(color: CwColors.white, fontSize: 14.5),
              ),
            if (!isUser && !pending && onSpeak != null && text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  onTap: onSpeak,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up_outlined,
                            size: 14, color: CwColors.crimson),
                        SizedBox(width: 4),
                        Text(
                          'przeczytaj głosem',
                          style: TextStyle(
                              fontSize: 11, color: CwColors.crimson),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (modelName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  modelName!,
                  style:
                      const TextStyle(fontSize: 10, color: CwColors.whiteDim),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BusyRow extends StatelessWidget {
  const _BusyRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: CwColors.crimson,
            ),
          ),
          SizedBox(width: 10),
          Text('Wilki myślą…',
              style: TextStyle(color: CwColors.whiteDim, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({required this.controller, required this.chat});

  final TextEditingController controller;
  final ChatController chat;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _micOn = false;

  @override
  void initState() {
    super.initState();
    widget.chat.micWords.listen((words) {
      widget.controller.text = words;
      widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length));
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Menu „+” — generowanie: tekst / obraz / głos
            PopupMenuButton<String>(
              tooltip: 'Generuj',
              icon: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CwColors.crimson,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: CwColors.white),
              ),
              color: CwColors.surfaceAlt,
              onSelected: (v) {
                if (v == 'image') _promptImage(context);
                if (v == 'voice') chat.speakLast();
                if (v == 'audio') _promptAudio(context);
                if (v == 'video') _promptVideo(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'text',
                  enabled: false,
                  child: Text('📝 Tekst — pisz w polu poniżej'),
                ),
                PopupMenuItem(
                  value: 'image',
                  child: Text('🖼 Obraz — wygeneruj grafikę'),
                ),
                PopupMenuItem(
                  value: 'voice',
                  child: Text('🔊 Dźwięk — przeczytaj odpowiedź'),
                ),
                PopupMenuItem(
                  value: 'audio',
                  child: Text('🎵 Audio — synteza mowy'),
                ),
                PopupMenuItem(
                  value: 'video',
                  child: Text('🎬 Wideo — opis sceny (AI)'),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Pisz do Wilków…',
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            _MicButton(
              active: _micOn,
              onToggle: () async {
                if (_micOn) {
                  await chat.stopMic();
                } else {
                  final ok = await chat.startMic();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Rozpoznawanie mowy niedostępne na tym urządzeniu.'),
                      ),
                    );
                  }
                }
                setState(() => _micOn = chat.micActive);
              },
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: chat.busy ? null : _send,
                child: const Icon(Icons.arrow_upward),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.controller.clear();
    widget.chat.send(text);
  }

  void _promptImage(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CwColors.surface,
        title: const Text('🖼 Generowanie obrazu'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Opisz obraz, który mam wygenerować…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              final p = ctrl.text.trim();
              Navigator.pop(ctx);
              if (p.isNotEmpty) widget.chat.generateImage(p);
            },
            child: const Text('Generuj'),
          ),
        ],
      ),
    );
  }

  void _promptAudio(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CwColors.surface,
        title: const Text('🎵 Synteza mowy'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Tekst do odczytania głosem agenta…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              final p = ctrl.text.trim();
              Navigator.pop(ctx);
              if (p.isNotEmpty) widget.chat.generateAudio(p);
            },
            child: const Text('Syntezuj'),
          ),
        ],
      ),
    );
  }

  void _promptVideo(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CwColors.surface,
        title: const Text('🎬 Opis wideo (AI)'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Opisz scenę, którą agent ma zinterpretować…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              final p = ctrl.text.trim();
              Navigator.pop(ctx);
              if (p.isNotEmpty) {
                widget.chat.send(
                  'Wygeneruj szczegółowy opis sceny wideo na podstawie: $p');
              }
            },
            child: const Text('Generuj opis'),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.active, required this.onToggle});

  final bool active;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: active ? CwColors.crimson : CwColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: CwColors.white, width: 1.5) : null,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onToggle,
        icon: Icon(
          active ? Icons.stop : Icons.mic_none,
          color: active ? CwColors.white : CwColors.whiteDim,
        ),
      ),
    );
  }
}
