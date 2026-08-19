import 'package:flutter/material.dart';

import '../core/constants.dart';

/// Nagłówek z logotypem — centralny punkt wizualny (wymaganie wizualne).
/// Używa oryginalnego pliku `assets/images/logo.png` bez modyfikacji.
class LogoHeader extends StatelessWidget {
  final double size;
  final bool showSubtitle;

  const LogoHeader({super.key, this.size = 72, this.showSubtitle = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            AppConstants.logoPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.cruelty_free,
              size: size,
              color: AppColors.red,
            ),
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 6),
          Text(
            AppConstants.appName,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Text(
            AppConstants.appSlogan,
            style: TextStyle(color: AppColors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
