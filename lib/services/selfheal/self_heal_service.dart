import 'package:flutter/services.dart';

/// Mechanizm samonaprawy i iniekcji kodu w locie (wymaganie #11).
///
/// - Android: dynamiczne ładowanie klas przez natywny most (DexClassLoader
///   w `SelfHealService.kt`) — nowy kod bez reinstalacji aplikacji.
/// - Desktop: modyfikacja plików źródłowych (patrz `applySourcePatch`).
class SelfHealService {
  static const MethodChannel _channel =
      MethodChannel('czarne_wilki/selfheal');

  /// Inicjuje moduł samonaprawy (Android: rejestruje ClassLoader).
  Future<bool> init() async {
    try {
      return await _channel.invokeMethod<bool>('init') ?? false;
    } on MissingPluginException {
      return false; // desktop: samonaprawa przez pliki źródłowe
    }
  }

  /// Wstrzykuje skompilowany plik `.dex` (Android) do aktualnego procesu.
  Future<bool> loadDex(String dexPath) async {
    try {
      return await _channel.invokeMethod<bool>('loadDex', {
            'path': dexPath,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Wywołuje metodę z dynamicznie załadowanej klasy (jeśli istnieje).
  Future<dynamic> invokeClass(
    String className,
    String methodName, {
    List<dynamic>? args,
  }) async {
    try {
      return await _channel.invokeMethod('invokeClass', {
        'className': className,
        'methodName': methodName,
        'args': args ?? const [],
      });
    } on MissingPluginException {
      return null;
    }
  }

  /// Desktop: wstrzykuje łatkę do pliku źródłowego (bezpieczna edycja z
  /// walidacją przed zapisem). Zwraca liczbę zmodyfikowanych linii.
  Future<int> applySourcePatch({
    required String filePath,
    required String marker,
    required String patch,
  }) async {
    try {
      return await _channel.invokeMethod<int>('applySourcePatch', {
            'filePath': filePath,
            'marker': marker,
            'patch': patch,
          }) ??
          0;
    } on MissingPluginException {
      return 0;
    }
  }
}
