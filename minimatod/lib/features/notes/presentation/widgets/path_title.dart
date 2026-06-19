import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/note_model.dart';

/// The AppBar title on a detail page, rendered as a compact, horizontally
/// scrollable path: `⌂ Home › … › current`. Tapping an ancestor crumb (or Home)
/// navigates there via [onCrumbTap] (null id = Home/root). Dragging an item onto
/// a crumb re-parents it there via [onCrumbDrop] — the easy way to move an item
/// back up to Home or any ancestor.
///
/// It lives in the title slot (not its own row) so the path costs no extra
/// vertical space.
class PathTitle extends StatefulWidget {
  const PathTitle({
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
  State<PathTitle> createState() => _PathTitleState();
}

class _PathTitleState extends State<PathTitle> {
  final ScrollController _scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep the current crumb in view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    final crumbs = <Widget>[
      _Crumb(
        label: l.home,
        icon: Icons.home_rounded,
        isCurrent: false,
        targetId: null,
        onTap: () => widget.onCrumbTap(null),
        onDrop: widget.onCrumbDrop,
      ),
    ];

    for (var i = 0; i < widget.path.length; i++) {
      final item = widget.path[i];
      final isCurrent = i == widget.path.length - 1;
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
          onTap: isCurrent ? null : () => widget.onCrumbTap(item.id),
          onDrop: widget.onCrumbDrop,
        ));
    }

    return SizedBox(
      height: 40,
      child: ListView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in crumbs) Center(child: c),
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
    final color = isCurrent ? cs.onSurface : cs.onSurface.withValues(alpha: 0.55);

    final Color background;
    if (highlighted) {
      background = cs.primary.withValues(alpha: 0.22);
    } else {
      background = Colors.transparent;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: highlighted
              ? Border.all(color: cs.primary.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isCurrent ? 17 : 15,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.3,
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
