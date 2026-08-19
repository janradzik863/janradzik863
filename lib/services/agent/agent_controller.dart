import 'package:flutter/foundation.dart';

import '../llm_service.dart';
import 'agent_action.dart';
import 'screen_control_bridge.dart';

/// Krok wykonany w pętli (dla logu / monitorowania postępu).
class AgentStep {
  final int index;
  final String actionDescription;
  final bool success;
  final String? note;

  AgentStep({
    required this.index,
    required this.actionDescription,
    required this.success,
    this.note,
  });
}

enum AgentState { idle, running, done, error, cancelled }

/// Rdzeń agenta automatyzacji Androida — ciągła pętla sprzężenia zwrotnego.
///
///  1. Użytkownik wydaje polecenie (głos / tekst / Telegram).
///  2. Agent rejestruje hierarchię ekranu (`ScreenControlBridge.hierarchy`).
///  3. Dane układu + kontekst zadania + wynik poprzedniej akcji trafiają do AI.
///  4. AI decyduje o kolejnej akcji (klik współrzędnych, tekst, przewijanie…).
///  5. Natywna warstwa (`ScreenControlService`) wykonuje akcję.
///  6. Pętla trwa aż akcja `done` lub wyczerpanie limitu kroków.
class AgentController extends ChangeNotifier {
  final LlmService _llm = LlmService();
  final ScreenControlBridge _bridge = ScreenControlBridge();

  AgentState _state = AgentState.idle;
  AgentState get state => _state;

  final List<AgentStep> _steps = [];
  List<AgentStep> get steps => List.unmodifiable(_steps);

  String _command = '';
  String get command => _command;

  String? _summary;
  String? get summary => _summary;

  String? _error;
  String? get error => _error;

  bool _running = false;
  bool get running => _running;

  /// Konfiguracja pętli (z AppSettings).
  int maxSteps = 20;
  Duration stepDelay = const Duration(milliseconds: 700);

  /// Uruchamia zadanie w języku naturalnym.
  Future<void> run({
    required String command,
    required bool online,
    required String model,
    required String systemPrompt,
  }) async {
    if (_running) return;
    _running = true;
    _command = command;
    _steps.clear();
    _summary = null;
    _error = null;
    _setState(AgentState.running);

    final history = <String>[]; // opis wykonanych akcji

    try {
      for (var i = 0; i < maxSteps; i++) {
        // 1. Rejestracja hierarchii ekranu.
        final nodes = await _bridge.hierarchy();

        // 2. Budowa promptu dla AI.
        final prompt = _buildPrompt(command, nodes, history, i);

        // 3. Decyzja AI.
        final response = await _llm.raw(
          prompt,
          online: online,
          model: model,
        );

        // 4. Parsowanie akcji.
        final action = AgentAction.parse(response);
        if (action == null) {
          history.add('krok ${i + 1}: niepoprawna odpowiedź AI (ponawiam)');
          _steps.add(AgentStep(
            index: i,
            actionDescription: 'niepoprawna odpowiedź (ponawiam)',
            success: false,
            note: response.length > 80
                ? response.substring(0, 80)
                : response,
          ));
          notifyListeners();
          continue;
        }

        // 5. Zakończenie zadania.
        if (action is DoneAction) {
          _summary = action.summary;
          _steps.add(AgentStep(
            index: i,
            actionDescription: action.toString(),
            success: true,
          ));
          _setState(AgentState.done);
          return;
        }

        // 6. Wykonanie akcji przez natywną warstwę.
        final ok = await _execute(action);
        history.add('krok ${i + 1}: ${action.toString()} -> ${ok ? "ok" : "błąd"}');
        _steps.add(AgentStep(
          index: i,
          actionDescription: action.toString(),
          success: ok,
        ));
        notifyListeners();

        // Krótka pauza, by UI zdążył się zaktualizować.
        await Future.delayed(stepDelay);
      }
      // Limit kroków.
      _error = 'Osiągnięto limit $maxSteps kroków bez zakończenia zadania.';
      _setState(AgentState.error);
    } catch (e) {
      _error = e.toString();
      _setState(AgentState.error);
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<bool> _execute(AgentAction action) async {
    switch (action) {
      case ClickAction(:final x, :final y):
        return _bridge.click(x, y);
      case ClickTextAction(:final text):
        return _bridge.clickText(text);
      case TypeAction(:final text):
        return _bridge.type(text);
      case ScrollAction(:final direction):
        return _bridge.scroll(direction);
      case GlobalAction(:final action):
        return _bridge.global(action);
      default:
        return false;
    }
  }

  String _buildPrompt(
    String command,
    List<ScreenNode> nodes,
    List<String> history,
    int step,
  ) {
    final screenDesc = nodes.isEmpty
        ? '(brak elementów z tekstem — ekran może być pusty lub usługa dostępności wyłączona)'
        : nodes.map((n) => n.toString()).join('\n');
    final historyDesc =
        history.isEmpty ? '(brak — to pierwszy krok)' : history.join('\n');

    return '''
Jesteś agentem automatyzacji ekranu Androida. Sterujesz urządzeniem przez
usługę dostępności, wykonując zadanie krok po kroku.

ZADANIE UŻYTKOWNIKA:
$command

AKTUALNA HIERARCHIA EKRANU (węzły z tekstem i współrzędnymi środka w px):
$screenDesc

HISTORIA DOTYCHCZASOWYCH AKCJI:
$historyDesc

ODPOWIEDZ WYŁĄCZNIE JEDNYM OBIEKTEM JSON opisującym NASTĘPNĄ pojedynczą
akcję. Dozwolone wartości pola "action":

- {"action":"click","x":<int>,"y":<int>}          — stuknij w podane współrzędne
- {"action":"click_text","text":"<dokładny tekst>"} — stuknij element o tym tekście
- {"action":"type","text":"<treść>"}              — wpisz tekst w aktywne pole
- {"action":"scroll","direction":"down"|"up"}     — przewiń ekran
- {"action":"back"}                               — cofnij
- {"action":"home"}                               — przejdź do ekranu głównego
- {"action":"done","summary":"<krótkie podsumowanie>"} — gdy zadanie zakończone

Wybierz dokładnie jedną akcję. Jeśli zadanie jest już wykonane, użyj "done".
Nie dodawaj tekstu poza JSON.
''';
  }

  void _setState(AgentState s) {
    _state = s;
    notifyListeners();
  }

  void reset() {
    if (_running) return;
    _state = AgentState.idle;
    _steps.clear();
    _summary = null;
    _error = null;
    _command = '';
    notifyListeners();
  }
}
