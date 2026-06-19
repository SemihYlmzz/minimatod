import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/note_model.dart';

/// A horizontally-scrollable breadcrumb trail shown under the AppBar on nested
/// screens: `Home › … › current`. Tapping an ancestor crumb (or Home) asks the
/// caller to navigate there via [onCrumbTap] (null id = Home/root).
///
/// Implements [PreferredSizeWidget] so it can be used as `AppBar.bottom`.
class BreadcrumbBar extends StatelessWidget implements PreferredSizeWidget {
  const BreadcrumbBar({
    super.key,
    required this.path,
    required this.onCrumbTap,
    required this.onCrumbDrop,
  });

  /// Ancestor chain root → … → current item.
  final List<Item> path;

  /// Called with the target item's id, or null for Home (root level).
  final ValueChanged<String?> onCrumbTap;

  /// Called when a dragged item is dropped on a crumb to re-parent it there
  /// (id null = move to the root level).
  final void Function(String? id, Item dragged) onCrumbDrop;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    final crumbs = <Widget>[
      _Crumb(
        label: l.home,
        icon: Icons.home_outlined,
        isCurrent: false,
        targetId: null,
        onTap: () => onCrumbTap(null),
        onDrop: onCrumbDrop,
      ),
    ];

    for (var i = 0; i < path.length; i++) {
      final item = path[i];
      final isCurrent = i == path.length - 1;
      crumbs
        ..add(Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: cs.onSurface.withValues(alpha: 0.3),
        ))
        ..add(_Crumb(
          label: item.content,
          isCurrent: isCurrent,
          targetId: item.id,
          onTap: isCurrent ? null : () => onCrumbTap(item.id),
          onDrop: onCrumbDrop,
        ));
    }

    return SizedBox(
      height: preferredSize.height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final c in crumbs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Center(child: c),
            ),
        ],
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.label,
    required this.isCurrent,
    required this.onTap,
    required this.targetId,
    required this.onDrop,
    this.icon,
  });

  final String label;
  final bool isCurrent;
  final VoidCallback? onTap;

  /// The item id this crumb re-parents dropped items to (null = root/Home).
  final String? targetId;
  final void Function(String? id, Item dragged) onDrop;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Item>(
      onWillAcceptWithDetails: (d) => d.data.parentId != targetId,
      onAcceptWithDetails: (d) => onDrop(targetId, d.data),
      builder: (context, candidate, rejected) =>
          _chip(context, highlighted: candidate.isNotEmpty),
    );
  }

  Widget _chip(BuildContext context, {required bool highlighted}) {
    final cs = Theme.of(context).colorScheme;
    final color = isCurrent ? cs.onSurface : cs.onSurface.withValues(alpha: 0.6);

    final Color background;
    if (highlighted) {
      background = cs.primary.withValues(alpha: 0.22);
    } else if (isCurrent) {
      background = cs.surfaceContainerHighest.withValues(alpha: 0.5);
    } else {
      background = Colors.transparent;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: highlighted
              ? Border.all(color: cs.primary.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
