import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// The ultimate-minimalist add affordance: a thin `+` glyph centered in a short
/// bottom strip — no bar background, no border.
class AddBar extends StatelessWidget {
  const AddBar({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 56,
        child: Center(
          child: IconButton(
            tooltip: l.add,
            onPressed: onAdd,
            icon: Icon(
              Icons.add,
              size: 26,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
