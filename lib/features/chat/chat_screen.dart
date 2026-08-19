import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import '../../core/constants.dart';
import '../../data/models.dart';
import '../../services/llm_service.dart';
import '../../state/app_state.dart';
import '../../widgets/logo_header.dart';

/// Minimalistyczny czat (wymaganie #6): menu podręczne ukryte pod ikoną
/// plusa dla generowania tekstu / obrazu / dźwięku / wideo.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _llm = LlmService();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final state = context.read<AppState>();
    await state.sendMessage(text);
    _scrollToBottom();

    setState(() => _busy = true);
    final reply = await _llm.complete(
      online: state.onlineMode,
      model: state.activeModel,
      agent: state.agent,
      history: state.messages,
    );
    setState(() => _busy = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: LogoHeader(size: 34, showSubtitle: false),
        ),
        title: const Text(AppConstants.appName),
        actions: [
          // Tryb online/offline (#5)
          IconButton(
            tooltip: state.onlineMode ? 'Tryb sieciowy' : 'Tryb offline',
            icon: Icon(
              state.onlineMode ? Icons.cloud_done : Icons.cloud_off,
              color: state.onlineMode ? AppColors.red : AppColors.white,
            ),
            onPressed: () => state.setOnlineMode(!state.onlineMode),
          ),
          IconButton(
            tooltip: 'Agent automatyzacji',
            icon: const Icon(Icons.smart_toy),
            onPressed: () =>
                Navigator.pushNamed(context, AppRouter.automation),
          ),
          IconButton(
            tooltip: 'Ustawienia',
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.pushNamed(context, AppRouter.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyState(state: state)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: state.messages.length + (_busy ? 1 : 0),
                    itemBuilder: (c, i) {
                      if (i == state.messages.length) {
                        return const _TypingBubble();
                      }
                      return _MessageBubble(msg: state.messages[i]);
                    },
                  ),
          ),
          _InputBar(
            controller: _controller,
            busy: _busy,
            recording: state.recording,
            onSend: _send,
            onToggleMic: () => state.recording
                ? state.stopListening()
                : state.startListening(),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppState state;
  const _EmptyState({required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LogoHeader(size: 120),
          const SizedBox(height: 16),
          Text(
            state.onlineMode
                ? 'Tryb sieciowy — model: ${state.activeModel}'
                : 'Tryb offline — inferencja 100% na urządzeniu',
            style: const TextStyle(color: AppColors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Przytrzymaj mikrofon, aby mówić. Zatrzymaj przyciskiem Stop.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? AppColors.red : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg.content,
          style: const TextStyle(color: AppColors.white),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.red,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final bool recording;
  final VoidCallback onSend;
  final VoidCallback onToggleMic;

  const _InputBar({
    required this.controller,
    required this.busy,
    required this.recording,
    required this.onSend,
    required this.onToggleMic,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Menu podręczne ukryte pod ikoną plusa (#6)
            PopupMenuButton<String>(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.white),
              tooltip: 'Generuj',
              color: AppColors.surface,
              onSelected: (v) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Wybrano generowanie: $v')),
                );
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'text', child: Text('Generuj tekst')),
                PopupMenuItem(
                    value: 'image', child: Text('Generuj obraz')),
                PopupMenuItem(
                    value: 'audio', child: Text('Generuj dźwięk')),
                PopupMenuItem(
                    value: 'video', child: Text('Generuj wideo')),
              ],
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: recording ? 'Nasłuchuję…' : 'Napisz wiadomość…',
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              tooltip: recording ? 'Stop (mikrofon)' : 'Start (mikrofon)',
              icon: Icon(
                recording ? Icons.stop_circle : Icons.mic,
                color: recording ? AppColors.red : AppColors.white,
                size: 30,
              ),
              onPressed: onToggleMic,
            ),
            IconButton(
              tooltip: 'Wyślij',
              icon: const Icon(Icons.send, color: AppColors.red),
              onPressed: busy ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
