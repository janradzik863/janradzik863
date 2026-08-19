import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';

/// Punkt 21: Moduł dobrowolnych wpłat i wsparcia społecznościowego.
class DonationService extends ChangeNotifier {
  DonationService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;
  List<Donation> _donations = [];
  double _total = 0;

  List<Donation> get donations => _donations;
  double get total => _total;

  Future<void> load() async {
    _donations = await _db.listDonations();
    _total = await _db.totalDonations();
    notifyListeners();
  }

  /// Zarejestruj wpłatę. W produkcji integrowane z bramką płatności;
  /// tu zapisujemy deklarację do lokalnej bazy.
  Future<void> addDonation({
    required double amount,
    String donorName = 'Anonimowy Wilk',
    String message = '',
  }) async {
    await _db.addDonation(Donation(
      id: 0,
      donorName: donorName,
      amountPln: amount,
      message: message,
    ));
    await load();
  }
}
