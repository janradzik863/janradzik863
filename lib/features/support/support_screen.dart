import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/support/support_service.dart';

/// Ekran dobrowolnych wpłat i wsparcia społecznościowego (#21).
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SupportService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Wesprzyj projekt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Icon(Icons.favorite, color: AppColors.red, size: 56),
          ),
          const SizedBox(height: 12),
          const Text(
            'Dobrowolne wsparcie społecznościowe',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Każda wpłata wspiera rozwój „Czarne Wilki Prawdy".',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(Icons.savings, color: AppColors.red),
              title: const Text('Łączna kwota wsparcia',
                  style: TextStyle(color: AppColors.white)),
              trailing: Text(
                '${svc.totalDonated.toStringAsFixed(2)} PLN',
                style: const TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final m in svc.methods)
            Card(
              color: AppColors.surface,
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet,
                    color: AppColors.red),
                title: Text(m.name,
                    style: const TextStyle(color: AppColors.white)),
                subtitle: Text(m.description,
                    style: const TextStyle(color: Colors.grey)),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.grey),
                  tooltip: 'Kopiuj adres',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: m.destination));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Skopiowano adres dla ${m.name}')),
                    );
                  },
                ),
                onTap: () => _declare(context, svc, m),
              ),
            ),
        ],
      ),
    );
  }

  void _declare(BuildContext context, SupportService svc, DonationMethod m) {
    final amountCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Deklaracja wpłaty — ${m.name}',
            style: const TextStyle(color: AppColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Adres docelowy:\n${m.destination}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtl,
              style: const TextStyle(color: AppColors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Kwota (PLN)', prefixText: 'PLN '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountCtl.text.trim()) ?? 0;
              if (amount > 0) {
                svc.recordDonation(amount: amount, method: m.id);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Potwierdź'),
          ),
        ],
      ),
    );
  }
}
