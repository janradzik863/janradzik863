/// Polityka użytkowania modułu automatyzacji.
///
/// Agent działa wyłącznie na urządzeniu i w interesie jego właściciela.
/// Twarde zasady poniżej są wbudowane w prompt systemowy agenta oraz
/// egzekwowane w kodzie (TaskAgent._policyGate) — niezależnie od tego,
/// jaki model AI aktualnie steruje pętlą.
class AutomationPolicy {
  AutomationPolicy._();

  /// Zasady wbudowane w każdy prompt sterujący automatyzacją.
  static const String systemRules = '''
ZASADY DZIAŁANIA AGENTA AUTOMATYZACJI (nienegocjowalne):
1. Sterujesz wyłącznie urządzeniem właściciela i wykonujesz wyłącznie JEGO polecenia.
2. Nigdy nie podszywasz się pod człowieka wobec innych osób: nie publikujesz treści,
   nie komentujesz i nie odpowiadasz w imieniu człowieka na platformach
   społecznościowych, forach ani w komunikatorach osób trzecich.
3. Zadania na treści kierowane do innych ludzi (posty, komentarze, wiadomości)
   przygotowujesz jako SZKIC i przekazujesz właścicielowi do własnoręcznej
   akceptacji i wysłania.
4. Działasz jawnie: każda akcja jest rejestrowana w logu widocznym dla właściciela.
5. Nie usuwasz ani nie modyfikujesz danych bez jednoznecznego polecenia
   właściciela zawartego w celu zadania.
''';

  /// Wzorce celów odrzucanych na zawsze przez bramkę polityki.
  /// Dopasowanie = odmowa wykonania zadania z wyjaśnieniem.
  static const List<RegExp> _refusedPatterns = [
    RegExp(r'opublikuj|publikacj\w+ (post|wpis)', caseSensitive: false),
    RegExp(r'skomentuj|dodaj komentarz|odpisz na komentarz', caseSensitive: false),
    RegExp(r'udostępnij (post|wpis|zdjęcie|film)', caseSensitive: false),
    RegExp(r'(facebook|instagram|tiktok|x\.com|twitter)\s*—?\s*(wyślij|post)', caseSensitive: false),
    RegExp(r'prowokuj|udawaj człowieka|udawać człowieka|pozoruj', caseSensitive: false),
    RegExp(r'masow\w+ (wiadomośc|komentarz|post)', caseSensitive: false),
  ];

  /// Wynik kontroli polityki.
  static String? refusalReason(String goal) {
    for (final p in _refusedPatterns) {
      if (p.hasMatch(goal)) {
        return 'Zadanie odrzucone przez politykę aplikacji: automatyzacja nie może '
            'publikować, komentować ani w inny sposób udawać ludzkiej aktywności '
            'wobec osób trzecich. Przygotuję szkic treści do Twojej własnoręcznej '
            'wysyłki — zmień polecenie w tym duchu.';
      }
    }
    return null;
  }
}
