import 'dart:async';
import 'dart:convert';

import '../core/policy.dart';
import '../engine/ai_engine.dart';
import 'accessibility_bridge.dart';

/// Agent operacyjny: pętla sprzężenia zwrotnego
/// ekran → AI → akcja → ekran, aż do wykonania zadania.
///
/// Każdy krok jest jawnie rejestrowany w logu (widocznym w UI),
/// a zadania sprzeczne z [AutomationPolicy] są odrzucane przed startem.
class TaskAgent {
  TaskAgent({
    required this.engineGetter,
    AccessibilityBridge? bridge,
    this.maxSteps = 25,
  }) : bridge = bridge ?? AccessibilityBridge();

  /// Dostarcza aktualnie aktywny silnik AI (lokalny lub chmurowy).
  final AiEngine? Function() engineGetter;
  final AccessibilityBridge bridge;
  final int maxSteps;

  final _logCtrl = StreamController<AgentLogEntry>.broadcast();
  final _stateCtrl = StreamController<AgentState>.broadcast();

  Stream<AgentLogEntry> get onLog => _logCtrl.stream;
  Stream<AgentState> get onState => _stateCtrl.stream;

  AgentState _state = AgentState.idle;
  bool _cancelled = false;

  AgentState get state => _state;

  void _log(String message, {bool ok = true}) {
    _logCtrl.add(AgentLogEntry(
      time: DateTime.now(),
      message: message,
      ok: ok,
    ));
  }

  /// Ręczne przerwanie pętli (przycisk STOP).
  void cancel() {
    _cancelled = true;
    _log('Zatrzymano przez użytkownika (STOP).', ok: false);
  }

  Future<void> run(String goal) async {
    if (_state == AgentState.running) return;

    // Bramka polityki — sprawdzana w kodzie, nie tylko w prompcie.
    final refusal = AutomationPolicy.refusalReason(goal);
    if (refusal != null) {
      _log(refusal, ok: false);
      return;
    }

    final engine = engineGetter();
    if (engine == null) {
      _log('Brak aktywnego silnika AI. Wybierz model (tryb Offline wymaga '
          'modelu lokalnego; chmura wymaga trybu Sieciowego).', ok: false);
      return;
    }
    if (!await bridge.isConnected()) {
      _log('Usługa dostępności „Czarne Wilki — Sterowanie Ekranem” jest '
          'wyłączona. Włącz ją w ustawieniach systemowych.', ok: false);
      return;
    }

    _cancelled = false;
    _state = AgentState.running;
    _stateCtrl.add(_state);
    _log('Start zadania: „$goal” (silnik: ${engine.displayName}).');

    String? lastAction;
    String? lastResult;

    try {
      for (var step = 1; step <= maxSteps; step++) {
        if (_cancelled) break;

        final tree = await bridge.screenTree();
        if (tree == null) {
          _log('Nie udało się odczytać ekranu (drzewo niedostępne).', ok: false);
          break;
        }

        _log('Krok $step: odczytano ekran ${tree.packageName} '
            '(${tree.nodes.length} elementów).');

        final answer = await _askEngine(
          engine,
          goal: goal,
          screen: tree.compact(),
          lastAction: lastAction,
          lastResult: lastResult,
        );

        final action = AgentAction.parse(answer);
        if (action == null) {
          _log('Model zwrócił niezrozumiałą odpowiedź — przerywam pętlę.',
              ok: false);
          break;
        }

        lastAction = action.describe();
        _log('→ ${action.describe()}');

        if (_cancelled) break;

        switch (action.kind) {
          case AgentActionKind.done:
            _log('Zadanie ukończone: ${action.text.isEmpty ? 'gotowe' : action.text}');
            _state = AgentState.finished;
            _stateCtrl.add(_state);
            return;
          case AgentActionKind.fail:
            _log('Model zgłosił brak możliwości wykonania: ${action.text}',
                ok: false);
            _state = AgentState.failed;
            _stateCtrl.add(_state);
            return;
          default:
            lastResult = await _execute(action, tree);
        }

        // Chwila na odświeżenie ekranu po akcji.
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }

      if (!_cancelled) {
        _log('Osiągnięto limit kroków ($maxSteps) — zatrzymano.', ok: false);
      }
      _state = AgentState.idle;
      _stateCtrl.add(_state);
    } finally {
      _state = _state == AgentState.running ? AgentState.idle : _state;
      _stateCtrl.add(_state);
    }
  }

  Future<String> _askEngine(
    AiEngine engine, {
    required String goal,
    required String screen,
    String? lastAction,
    String? lastResult,
  }) async {
    final buffer = StringBuffer();
    try {
      await for (final chunk in engine.chat(
        system: _systemPrompt,
        turns: [
          (
            'user',
            _userPrompt(goal, screen, lastAction, lastResult),
          ),
        ],
        temperature: 0.2,
        maxTokens: 400,
      )) {
        buffer.write(chunk);
      }
    } on AiEngineException catch (e) {
      return '{"action":"fail","text":"błąd silnika: ${e.message}"}';
    }
    return buffer.toString();
  }

  static const _systemPrompt = '''
${AutomationPolicy.systemRules}
Jesteś agentem operacyjnym sterującym urządzeniem Android właściciela.
Otrzymujesz CEL, opis aktualnego ekranu oraz wynik poprzedniej akcji.
Decydujesz o JEDNEJ kolejnej akcji. Odpowiadasz WYŁĄCZNIE jednym obiektem JSON:
{"action":"tap","x":123,"y":456,"why":"krótko"}                      // stuknięcie we współrzędne
{"action":"type","node":"#12","text":"treść","why":"krótko"}         // wpisanie tekstu w pole
{"action":"scroll","dir":"down","why":"krótko"}                      // przewinięcie (up/down/left/right)
{"action":"back"} / {"action":"home"}                                // nawigacja systemowa
{"action":"done","text":"co wykonano"}                               // cel osiągnięty
{"action":"fail","text":"dlaczego"}                                  // cel niewykonalny
Zasady: wybieraj elementy po współrzędnych środka z opisu ekranu; nie wymyślaj
współrzędnych spoza ekranu; jeśli zadanie wymaga treści dla innych ludzi,
zatrzymaj się i zwróć "done" z informacją, że przygotowano szkic do
własnoręcznej akceptacji właściciela.
''';

  String _userPrompt(
    String goal,
    String screen,
    String? lastAction,
    String? lastResult,
  ) {
    final b = StringBuffer()
      ..writeln('CEL: $goal')
      ..writeln();
    if (lastAction != null) {
      b
        ..writeln('POPRZEDNIA AKCJA: $lastAction')
        ..writeln('WYNIK: ${lastResult ?? 'brak informacji'}')
        ..writeln();
    }
    b
      ..writeln('AKTUALNY EKRAN:')
      ..writeln(screen)
      ..writeln()
      ..writeln('Podaj następny krok jako JSON.');
    return b.toString();
  }

  Future<String> _execute(AgentAction a, ScreenTree tree) async {
    switch (a.kind) {
      case AgentActionKind.tap:
        final ok = await bridge.tap(a.x, a.y);
        return ok ? 'stuknięcie wykonane' : 'stuknięcie nieudane';
      case AgentActionKind.type:
        final node = a.nodeId == null
            ? null
            : tree.nodes.where((n) => n.id == a.nodeId).firstOrNull;
        if (node == null) {
          // Awaryjnie: stukamy w pierwszy edytowalny element i wpisujemy.
          final editable =
              tree.nodes.where((n) => n.editable).firstOrNull;
          if (editable == null) return 'brak pola edytowalnego';
          await bridge.tap(editable.centerX, editable.centerY);
          await Future<void>.delayed(const Duration(milliseconds: 400));
          final ok = await bridge.setText(editable.id, a.text);
          return ok ? 'wpisano tekst' : 'wpisywanie nieudane';
        }
        final ok = await bridge.setText(node.id, a.text);
        return ok ? 'wpisano tekst' : 'wpisywanie nieudane';
      case AgentActionKind.scroll:
        const pad = 120;
        final midX = tree.width ~/ 2;
        final ok = switch (a.dir) {
          'up' => await bridge.swipe(
              midX, pad, midX, tree.height - pad, 350),
          'left' => await bridge.swipe(
              tree.width - pad, tree.height ~/ 2, pad, tree.height ~/ 2, 350),
          'right' => await bridge.swipe(
              pad, tree.height ~/ 2, tree.width - pad, tree.height ~/ 2, 350),
          _ => await bridge.swipe(
              midX, tree.height - pad, midX, pad, 350),
        };
        return ok ? 'przewinięto ${a.dir}' : 'przewijanie nieudane';
      case AgentActionKind.back:
        final ok = await bridge.globalAction('back');
        return ok ? 'wstecz' : 'akcja wstecz nieudana';
      case AgentActionKind.home:
        final ok = await bridge.globalAction('home');
        return ok ? 'ekran główny' : 'akcja home nieudana';
      default:
        return '—';
    }
  }
}

enum AgentState { idle, running, finished, failed }

class AgentLogEntry {
  AgentLogEntry({required this.time, required this.message, required this.ok});

  final DateTime time;
  final String message;
  final bool ok;
}

enum AgentActionKind { tap, type, scroll, back, home, done, fail }

class AgentAction {
  AgentAction(
    this.kind, {
    this.x = 0,
    this.y = 0,
    this.text = '',
    this.nodeId,
    this.dir = 'down',
    this.why = '',
  });

  final AgentActionKind kind;
  final int x;
  final int y;
  final String text;
  final String? nodeId;
  final String dir;
  final String why;

  String describe() {
    switch (kind) {
      case AgentActionKind.tap:
        return 'stuknięcie ($x, $y)${why.isEmpty ? '' : ' — ${why}'}';
      case AgentActionKind.type:
        return 'wpisanie tekstu do ${nodeId ?? '?'}: „${text.length > 40 ? '${text.substring(0, 40)}…' : text}”';
      case AgentActionKind.scroll:
        return 'przewinięcie $dir${why.isEmpty ? '' : ' — ${why}'}';
      case AgentActionKind.back:
        return 'nawigacja: wstecz';
      case AgentActionKind.home:
        return 'nawigacja: ekran główny';
      case AgentActionKind.done:
        return 'UKOŃCZONO: $text';
      case AgentActionKind.fail:
        return 'PORAZKA: $text';
    }
  }

  /// Robustny parser: wyjmuje pierwszy sensowny obiekt JSON z odpowiedzi.
  static AgentAction? parse(String raw) {
    final start = raw.indexOf('{');
    var end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    var json = raw.substring(start, end + 1);
    // Usuń bloki kodu i śmieci wokół, jeśli występują.
    if (json.contains('```')) return null;
    try {
      return _fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  static AgentAction _fromJsonString(String s) {
    // ignore: avoid_dynamic_calls
    final map = const JsonDecoder().convert(s) as Map<String, dynamic>;
    final kind = AgentActionKind.values.firstWhere(
      (k) => k.name == (map['action'] as String? ?? ''),
      orElse: () => AgentActionKind.fail,
    );
    return AgentAction(
      kind,
      x: (map['x'] as num?)?.toInt() ?? 0,
      y: (map['y'] as num?)?.toInt() ?? 0,
      text: map['text'] as String? ?? '',
      nodeId: map['node'] as String?,
      dir: map['dir'] as String? ?? 'down',
      why: map['why'] as String? ?? '',
    );
  }
}
