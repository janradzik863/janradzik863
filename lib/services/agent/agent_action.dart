import 'dart:convert';

/// Akcja wygenerowana przez AI w pętli sprzężenia zwrotnego agenta.
sealed class AgentAction {
  const AgentAction();

  /// Próbuje sparsować odpowiedź AI na konkretną akcję.
  /// Zwraca null, jeśli nie da się rozpoznać akcji (AI ma spróbować ponownie).
  static AgentAction? parse(String raw) {
    final json = _extractJson(raw);
    if (json == null) return null;
    final type = (json['action'] as String?)?.trim().toLowerCase();
    switch (type) {
      case 'click':
        final x = (json['x'] as num?)?.toDouble();
        final y = (json['y'] as num?)?.toDouble();
        if (x == null || y == null) return null;
        return ClickAction(x, y);
      case 'click_text':
      case 'tap_text':
        final text = (json['text'] as String?)?.trim();
        if (text == null || text.isEmpty) return null;
        return ClickTextAction(text);
      case 'type':
      case 'input':
      case 'text':
        final text = (json['text'] as String?) ?? '';
        if (text.isEmpty) return null;
        return TypeAction(text);
      case 'scroll':
        final dir = (json['direction'] as String?) ?? 'down';
        return ScrollAction(dir == 'up' ? 'up' : 'down');
      case 'back':
        return const GlobalAction('back');
      case 'home':
        return const GlobalAction('home');
      case 'done':
      case 'finish':
      case 'complete':
        final summary = (json['summary'] as String?) ?? 'Zadanie ukończone.';
        return DoneAction(summary);
      default:
        return null;
    }
  }

  /// Wyciąga obiekt JSON z odpowiedzi AI (toleruje markdown i dodatkowy tekst).
  static Map<String, dynamic>? _extractJson(String raw) {
    var s = raw.trim();
    // Usuń ewentualne bloki markdown ```json ... ```
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final m = fence.firstMatch(s);
    if (m != null) s = m.group(1)!.trim();
    // Znajdź pierwszy obiekt JSON { ... }
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(s.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
    return null;
  }
}

class ClickAction extends AgentAction {
  final double x;
  final double y;
  const ClickAction(this.x, this.y);
  @override
  String toString() => 'click (${x.toStringAsFixed(0)}, ${y.toStringAsFixed(0)})';
}

class ClickTextAction extends AgentAction {
  final String text;
  const ClickTextAction(this.text);
  @override
  String toString() => 'click_text "$text"';
}

class TypeAction extends AgentAction {
  final String text;
  const TypeAction(this.text);
  @override
  String toString() => 'type "$text"';
}

class ScrollAction extends AgentAction {
  final String direction; // "up" | "down"
  const ScrollAction(this.direction);
  @override
  String toString() => 'scroll $direction';
}

class GlobalAction extends AgentAction {
  final String action; // back | home
  const GlobalAction(this.action);
  @override
  String toString() => 'global $action';
}

class DoneAction extends AgentAction {
  final String summary;
  const DoneAction(this.summary);
  @override
  String toString() => 'done: $summary';
}
