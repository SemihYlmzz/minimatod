import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/note_model.dart';

/// The bottom strip: normally an ultra-minimal `+` to add an item. While an item
/// is being dragged ([dragActive]) it turns into a red trash drop target —
/// dropping an item there asks [onDeleteDrop] to confirm and delete it.
class AddBar extends StatelessWidget {
  const AddBar({
    super.key,
    required this.onAdd,
    this.dragActive = false,
    this.onDeleteDrop,
  });

  final VoidCallback onAdd;
  final bool dragActive;
  final ValueChanged<Item>? onDeleteDrop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    if (!dragActive) {
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

    return SafeArea(
      top: false,
      child: DragTarget<Item>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => onDeleteDrop?.call(d.data),
        builder: (context, candidate, rejected) {
          final hover = candidate.isNotEmpty;
          return SizedBox(
            height: 56,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: hover ? 56 : 44,
                height: hover ? 56 : 44,
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: hover ? 0.9 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_rounded,
                  size: hover ? 28 : 24,
                  color: hover ? cs.onError : cs.error,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
