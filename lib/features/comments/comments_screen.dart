import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/comments/comments_service.dart';
import '../../state/app_state.dart';

/// Aktywny agent w sekcji komentarzy (#18).
class CommentsScreen extends StatelessWidget {
  const CommentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<CommentsService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent w komentarzach'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Text('auto-odpowiedzi',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Switch(
                  value: svc.autoReply,
                  activeColor: AppColors.red,
                  onChanged: (v) => svc.setAutoReply(v),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: svc.comments.length,
        itemBuilder: (c, i) {
          final cm = svc.comments[i];
          return Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${cm.author}:',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(cm.text,
                      style: const TextStyle(color: AppColors.white)),
                  if (cm.hasReply) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.red),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🤖 Agent:',
                              style: TextStyle(
                                  color: AppColors.red, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(cm.agentReply!,
                              style: const TextStyle(color: AppColors.white)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Widok dodawania komentarza (do osadzenia pod postem).
class CommentComposer extends StatelessWidget {
  const CommentComposer({super.key});

  @override
  Widget build(BuildContext context) {
    final ctl = TextEditingController();
    final svc = context.read<CommentsService>();
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctl,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(
                hintText: 'Napisz komentarz…',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.red),
            onPressed: () {
              final text = ctl.text.trim();
              if (text.isEmpty) return;
              ctl.clear();
              svc.addComment(
                postId: 'demo-1',
                author: 'Ty',
                text: text,
                online: state.onlineMode,
                model: state.activeModel,
              );
            },
          ),
        ],
      ),
    );
  }
}
