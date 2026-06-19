import 'package:flutter/material.dart';

import '../../../../core/brand/logo_painter.dart';
import '../../../../l10n/app_localizations.dart';

/// Shown when a level has no items: a soft halo around the brand mark plus a
/// title and hint to add the first item.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Soft concentric halo around the brand mark.
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.04),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                ),
                alignment: Alignment.center,
                child: MinimatodLogo(
                  size: 46,
                  markColor: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l.emptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.emptySubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
