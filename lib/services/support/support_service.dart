import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Metoda płatności / wsparcia.
class DonationMethod {
  final String id;
  final String name;
  final String description;
  String destination; // adres portfela / link płatności / nr konta

  DonationMethod({
    required this.id,
    required this.name,
    required this.description,
    required this.destination,
  });
}

/// Rekord dobrowolnej wpłaty (lokalny rejestr — bez danych osobowych).
class Donation {
  final String id;
  final double amount;
  final String method;
  final String currency;
  final DateTime createdAt;

  Donation({
    required this.id,
    required this.amount,
    required this.method,
    required this.currency,
    required this.createdAt,
  });
}

/// Moduł dobrowolnych wpłat i wsparcia społecznościowego (wymaganie #21).
///
/// Prezentuje kanały wsparcia (portfel kryptowalutowy, link płatności,
/// przelew) i prowadzi lokalny rejestr zadeklarowanych wpłat. Żadne dane
/// płatnicze nie są przechowywane — wyłącznie deklaracja kwoty/metody.
class SupportService extends ChangeNotifier {
  final List<DonationMethod> _methods = [
    DonationMethod(
      id: 'crypto-btc',
      name: 'Bitcoin (BTC)',
      description: 'Dobrowolne wsparcie kryptowalutą.',
      destination: 'bc1qXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
    ),
    DonationMethod(
      id: 'crypto-eth',
      name: 'Ethereum (ETH)',
      description: 'Wsparcie w ETH / tokenach ERC-20.',
      destination: '0x0000000000000000000000000000000000000000',
    ),
    DonationMethod(
      id: 'blik',
      name: 'BLIK / przelew',
      description: 'Szybka wpłata krajowa.',
      destination: 'PL 00 0000 0000 0000 0000 0000 0000',
    ),
  ];

  final List<Donation> _donations = [];
  List<Donation> get donations => List.unmodifiable(_donations);
  List<DonationMethod> get methods => List.unmodifiable(_methods);

  static const _pref = 'support.donations';

  Future<void> init() async {
    await _loadMethods();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pref);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        _donations.add(Donation(
          id: e['id'] as String,
          amount: (e['amount'] as num).toDouble(),
          method: e['method'] as String,
          currency: e['currency'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(e['createdAt'] as int),
        ));
      }
    }
    notifyListeners();
  }

  double get totalDonated =>
      _donations.fold(0.0, (sum, d) => sum + d.amount);

  /// Aktualizuje adres docelowy metody wsparcia (ustawienia modułu #21).
  Future<void> updateMethod(String id, String destination) async {
    for (final m in _methods) {
      if (m.id == id) m.destination = destination.trim();
    }
    notifyListeners();
    await _saveMethods();
  }

  Future<void> _saveMethods() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'support.methods',
      jsonEncode(_methods
          .map((m) => {
                'id': m.id,
                'name': m.name,
                'description': m.description,
                'destination': m.destination,
              })
          .toList()),
    );
  }

  /// Wczytuje zapisane adresy (wołane w init).
  Future<void> _loadMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('support.methods');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final id = e['id'] as String;
        final dest = e['destination'] as String;
        for (final m in _methods) {
          if (m.id == id) m.destination = dest;
        }
      }
    } catch (_) {}
  }

  /// Rejestruje zadeklarowaną wpłatę (lokalnie).
  Future<void> recordDonation({
    required double amount,
    required String method,
    String currency = 'PLN',
  }) async {
    _donations.add(Donation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      method: method,
      currency: currency,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pref,
      jsonEncode(_donations
          .map((d) => {
                'id': d.id,
                'amount': d.amount,
                'method': d.method,
                'currency': d.currency,
                'createdAt': d.createdAt.millisecondsSinceEpoch,
              })
          .toList()),
    );
  }

  /// Pobiera aktualny adres portfela (z serwera projektu, jeśli online).
  /// Fallback: statyczny adres z listy metod.
  Future<String?> fetchWalletAddress(String methodId) async {
    final m = _methods.where((e) => e.id == methodId).toList();
    if (m.isEmpty) return null;
    try {
      final resp = await http.get(
        Uri.parse('https://czarnewilkiprawdy.example/support/$methodId'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['address'] as String?;
      }
    } catch (_) {
      // offline — zwróć statyczny adres
    }
    return m.first.destination;
  }
}
