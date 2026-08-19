import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/donation_service.dart';

/// Punkt 21: Moduł dobrowolnych wpłat i wsparcia społecznościowego.
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<DonationService>().load());
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DonationService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wesprzyj Wilki'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CwLogo(width: 120),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'CZARNE WILKI PRAWDY — WSZYSCY WON!',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: CwColors.crimson),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Każda wpłata pomaga rozwijać projekt — utrzymanie serwerów, '
            'rozwój kodu, niezależność od korporacji.',
            style: TextStyle(color: CwColors.whiteDim, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Suma wpłat
          Card(
            color: CwColors.crimsonDark,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('SUMA WSPARCIA',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: CwColors.white)),
                  const SizedBox(height: 8),
                  Text(
                    '${svc.total.toStringAsFixed(2)} PLN',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: CwColors.white),
                  ),
                  Text(
                    '${svc.donations.length} wpłat',
                    style: const TextStyle(
                        fontSize: 13, color: CwColors.whiteDim),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Przycisk wpłaty
          FilledButton.icon(
            onPressed: () => _showDonateDialog(context, svc),
            icon: const Icon(Icons.volunteer_activism),
            label: const Text('Wesprzyj projekt'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          const Text('LISTA WILKÓW WSPIERAJĄCYCH',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.whiteDim)),
          const SizedBox(height: 8),
          if (svc.donations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Bądź pierwszym wspierającym!',
                    style: TextStyle(color: CwColors.whiteDim)),
              ),
            )
          else
            for (final d in svc.donations)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: CwColors.crimsonDark,
                    child:
                        Icon(Icons.favorite, color: CwColors.white, size: 18),
                  ),
                  title: Text(d.donorName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (d.message.isNotEmpty)
                        Text(d.message,
                            style: const TextStyle(
                                fontSize: 12, color: CwColors.whiteDim)),
                      Text(
                        DateFormat('dd.MM.yyyy').format(d.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: CwColors.whiteDim),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${d.amountPln.toStringAsFixed(0)} PLN',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: CwColors.crimson),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _showDonateDialog(BuildContext context, DonationService svc) {
    final amountCtrl = TextEditingController(text: '20');
    final nameCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CwColors.surface,
        title: const Text('Wesprzyj Wilki'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Kwota (PLN)',
                suffixText: 'PLN',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Twoje imię (opcjonalne)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Wiadomość (opcjonalna)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              svc.addDonation(
                amount: amount,
                donorName: nameCtrl.text.trim().isEmpty
                    ? 'Anonimowy Wilk'
                    : nameCtrl.text.trim(),
                message: msgCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Wyślij wsparcie'),
          ),
        ],
      ),
    );
  }
}
