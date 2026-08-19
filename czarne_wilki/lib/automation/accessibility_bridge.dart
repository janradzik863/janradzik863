import 'dart:convert';

import 'package:flutter/services.dart';

/// Most do natywnej usługi dostępności Androida (Kotlin:
/// CwAccessibilityService). Zapewnia odczyt drzewa ekranu z dokładnymi
/// współrzędnymi elementów oraz wykonywanie akcji wejściowych.
class AccessibilityBridge {
  static const MethodChannel _ch = MethodChannel('cw/accessibility');

  /// Czy usługa „Czarne Wilki — Sterowanie Ekranem” jest włączona
  /// w ustawieniach dostępności systemu.
  Future<bool> isConnected() async {
    try {
      return await _ch.invokeMethod<bool>('isConnected') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Otwiera systemowe ustawienia dostępności.
  Future<void> openAccessibilitySettings() async {
    try {
      await _ch.invokeMethod<void>('openSettings');
    } catch (_) {}
  }

  /// Aktualna hierarchia ekranu z geometrią współrzędnych.
  Future<ScreenTree?> screenTree() async {
    try {
      final raw = await _ch.invokeMethod<String>('screenTree');
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ScreenTree.fromMap(map);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Stuknięcie we współrzędne ekranu.
  Future<bool> tap(int x, int y) async =>
      await _ch.invokeMethod<bool>('tap', {'x': x, 'y': y}) ?? false;

  /// Gest przeciągnięcia (przewijanie).
  Future<bool> swipe(int x1, int y1, int x2, int y2, int durationMs) async =>
      await _ch.invokeMethod<bool>('swipe', {
        'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'duration': durationMs,
      }) ?? false;

  /// Wpisanie tekstu do pola edytowalnego (ACTION_SET_TEXT na węźle).
  Future<bool> setText(String nodeId, String text) async =>
      await _ch.invokeMethod<bool>('setText', {'nodeId': nodeId, 'text': text}) ??
      false;

  /// Akcje globalne: back | home | recents | notifications.
  Future<bool> globalAction(String action) async =>
      await _ch.invokeMethod<bool>('globalAction', {'action': action}) ?? false;
}

class ScreenTree {
  ScreenTree({
    required this.packageName,
    required this.width,
    required this.height,
    required this.nodes,
  });

  final String packageName;
  final int width;
  final int height;
  final List<ScreenNode> nodes;

  static ScreenTree fromMap(Map<String, dynamic> map) => ScreenTree(
        packageName: map['package'] as String? ?? '',
        width: map['width'] as int? ?? 1080,
        height: map['height'] as int? ?? 2400,
        nodes: [
          for (final n in (map['nodes'] as List? ?? const []))
            ScreenNode.fromMap(n as Map<String, dynamic>),
        ],
      );

  /// Kompaktowa reprezentacja tekstowa drzewa dla modelu AI:
  /// [id] (środek_x,środek_y) klasa „tekst/opis” flagi.
  String compact() {
    final b = StringBuffer();
    b.writeln('APLIKACJA: $packageName ($width×$height)');
    b.writeln('ELEMENTY (id | współrzędne środka | typ | treść | akcje):');
    for (final n in nodes) {
      final flags = [
        if (n.clickable) 'klikalny',
        if (n.scrollable) 'przewijalny',
        if (n.editable) 'edytowalny',
      ].join(',');
      final label = [n.text, n.description]
          .where((s) => s.trim().isNotEmpty)
          .map((s) => '„${s.replaceAll('\n', ' ')}"')
          .join(' ');
      b.writeln(
          '#${n.id} (${n.centerX},${n.centerY}) ${n.shortClass} $label${flags.isEmpty ? '' : ' [$flags]'}');
    }
    return b.toString();
  }
}

class ScreenNode {
  ScreenNode({
    required this.id,
    required this.text,
    required this.description,
    required this.className,
    required this.l,
    required this.t,
    required this.r,
    required this.b,
    required this.clickable,
    required this.scrollable,
    required this.editable,
  });

  final String id;
  final String text;
  final String description;
  final String className;
  final int l, t, r, b;
  final bool clickable;
  final bool scrollable;
  final bool editable;

  int get centerX => (l + r) ~/ 2;
  int get centerY => (t + b) ~/ 2;

  String get shortClass {
    final parts = className.split('.');
    return parts.isEmpty ? className : parts.last;
  }

  static ScreenNode fromMap(Map<String, dynamic> m) => ScreenNode(
        id: m['id'] as String,
        text: m['text'] as String? ?? '',
        description: m['desc'] as String? ?? '',
        className: m['cls'] as String? ?? '',
        l: m['l'] as int? ?? 0,
        t: m['t'] as int? ?? 0,
        r: m['r'] as int? ?? 0,
        b: m['b'] as int? ?? 0,
        clickable: m['clickable'] as bool? ?? false,
        scrollable: m['scrollable'] as bool? ?? false,
        editable: m['editable'] as bool? ?? false,
      );
}
