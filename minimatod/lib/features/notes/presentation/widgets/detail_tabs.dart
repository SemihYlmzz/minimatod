import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// A minimal two-segment toggle (Items / Note) for the item detail page,
/// shown as the AppBar bottom. Reflects the current [index] and reports taps
/// via [onTap]; the active segment slides between the two with a filled pill.
///
/// Implements [PreferredSizeWidget] so it can be passed straight to
/// `AppBar.bottom`.
class DetailTabs extends StatelessWidget implements PreferredSizeWidget {
  const DetailTabs({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final labels = [l.tabItems, l.tabNote];

    return SizedBox(
      height: preferredSize.height,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Container(
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(11),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segWidth = constraints.maxWidth / 2;
                return Stack(
                  children: [
                    // Sliding active pill.
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      alignment: index == 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        width: segWidth,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: cs.shadow.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < 2; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTap(i),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  // Derive from the inherited style so the
                                  // platform/theme font carries through (rather
                                  // than a bare TextStyle that drops the family).
                                  style: DefaultTextStyle.of(context).style
                                      .copyWith(
                                        fontSize: 13.5,
                                        fontWeight: i == index
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: i == index
                                            ? cs.onSurface
                                            : cs.onSurface.withValues(
                                                alpha: 0.5,
                                              ),
                                      ),
                                  child: Text(labels[i]),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
