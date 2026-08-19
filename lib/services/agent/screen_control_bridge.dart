import 'package:flutter/services.dart';

/// Węzeł hierarchii ekranu odczytany z natywnej usługi dostępności.
class ScreenNode {
  final String text;
  final String description;
  final bool clickable;
  final bool editable;
  final bool scrollable;
  final String className;
  final double centerX;
  final double centerY;

  ScreenNode({
    required this.text,
    required this.description,
    required this.clickable,
    required this.editable,
    required this.scrollable,
    required this.className,
    required this.centerX,
    required this.centerY,
  });

  factory ScreenNode.fromMap(Map<dynamic, dynamic> m) => ScreenNode(
        text: (m['text'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        clickable: (m['clickable'] ?? false) as bool,
        editable: (m['editable'] ?? false) as bool,
        scrollable: (m['scrollable'] ?? false) as bool,
        className: (m['className'] ?? '') as String,
        centerX: ((m['centerX'] ?? 0) as num).toDouble(),
        centerY: ((m['centerY'] ?? 0) as num).toDouble(),
      );

  String get label {
    if (text.isNotEmpty) return text;
    if (description.isNotEmpty) return description;
    return className.split('.').last;
  }

  @override
  String toString() =>
      '[$label] @(${centerX.toStringAsFixed(0)},${centerY.toStringAsFixed(0)})'
      '${clickable ? ' clickable' : ''}${editable ? ' editable' : ''}';
}

/// Most do natywnej usługi sterowania ekranem (agent automatyzacji — #8).
///
/// Kanał `czarne_wilki/screen` obsługiwany jest w `MainActivity.kt` i woła
/// metody `ScreenControlService`.
class ScreenControlBridge {
  static const MethodChannel _channel =
      MethodChannel('czarne_wilki/screen');

  /// Czy usługa dostępności jest podłączona.
  Future<bool> isAvailable() async {
    try {
      await _channel.invokeMethod('clickable');
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'unavailable') return false;
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Rejestruje aktualną hierarchię ekranu (węzły z tekstem).
  Future<List<ScreenNode>> hierarchy() async {
    final raw = await _channel.invokeMethod('hierarchy') as List? ?? [];
    return raw
        .map((e) => ScreenNode.fromMap(e as Map))
        .where((n) => n.label.isNotEmpty)
        .toList();
  }

  /// Wykonuje stuknięcie po współrzędnych (geometria ekranu — #8).
  Future<bool> click(double x, double y) async {
    return await _channel.invokeMethod<bool>('click', {
          'x': x,
          'y': y,
        }) ??
        false;
  }

  /// Klika element po jego tekście.
  Future<bool> clickText(String text) async {
    return await _channel.invokeMethod<bool>('clickText', {'text': text}) ??
        false;
  }

  /// Wpisuje tekst w pierwsze pole edytowalne.
  Future<bool> type(String text) async {
    return await _channel.invokeMethod<bool>('type', {'text': text}) ?? false;
  }

  /// Przewija ekran w podanym kierunku ("up" / "down").
  Future<bool> scroll(String direction) async {
    return await _channel
            .invokeMethod<bool>('scroll', {'direction': direction}) ??
        false;
  }

  /// Akcja globalna: back / home / recents / notifications.
  Future<bool> global(String action) async {
    return await _channel.invokeMethod<bool>('global', {'action': action}) ??
        false;
  }
}
