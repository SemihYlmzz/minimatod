import 'package:flutter/material.dart';

import '../../../../core/format/created_at.dart';
import '../../data/note_model.dart';

/// A flat, tappable row for one item. Tapping opens the item's own screen;
/// long-press starts a drag to nest it inside another item (carried centered
/// under the finger); the trailing ⋯ opens the actions menu. The badges show
/// how many descendant **tasks** are completed / uncompleted (notes excluded).
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    required this.completedTasks,
    required this.uncompletedTasks,
    required this.canAcceptDrop,
    required this.onAcceptDrop,
    required this.onTap,
    required this.onToggleDone,
    required this.onMenu,
  });

  final Item item;
  final int completedTasks;
  final int uncompletedTasks;
  final bool Function(Item dragged) canAcceptDrop;
  final ValueChanged<Item> onAcceptDrop;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Item>(
      onWillAcceptWithDetails: (d) => canAcceptDrop(d.data),
      onAcceptWithDetails: (d) => onAcceptDrop(d.data),
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return LongPressDraggable<Item>(
          data: item,
          // Carry the tile centered under the finger.
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: _DragFeedback(item: item),
          ),
          childWhenDragging:
              Opacity(opacity: 0.4, child: _tile(context, false)),
          child: _tile(context, highlighted),
        );
      },
    );
  }

  Widget _tile(BuildContext context, bool highlighted) {
    final cs = Theme.of(context).colorScheme;
    final isTask = item.type == ItemType.task;
    final isDone = isTask && item.isDone;
    final hasTaskCounts = completedTasks > 0 || uncompletedTasks > 0;

    final accent = isTask ? cs.primary : cs.tertiary;
    final tileColor = highlighted
        ? cs.primary.withValues(alpha: 0.18)
        : cs.surfaceContainerHighest.withValues(alpha: isTask ? 0.5 : 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted
                    ? cs.primary.withValues(alpha: 0.6)
                    : cs.outline.withValues(alpha: 0.10),
                width: highlighted ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: isTask ? onToggleDone : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDone ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isTask
                          ? (isDone
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded)
                          : Icons.sticky_note_2_outlined,
                      size: isTask ? 22 : 19,
                      color: accent.withValues(
                          alpha: isTask && !isDone ? 0.7 : 1),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: isDone
                              ? cs.onSurface.withValues(alpha: 0.4)
                              : cs.onSurface.withValues(alpha: 0.92),
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatCreatedAt(
                            item.createdAt, Localizations.localeOf(context)),
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.2,
                          color: cs.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasTaskCounts) ...[
                  const SizedBox(width: 8),
                  _CountBadge(
                    icon: Icons.check_rounded,
                    count: completedTasks,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  _CountBadge(
                    icon: Icons.circle_outlined,
                    count: uncompletedTasks,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ],
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                  onPressed: onMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating tile shown under the finger while dragging an item.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTask = item.type == ItemType.task;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTask
                  ? Icons.check_circle_outline_rounded
                  : Icons.sticky_note_2_outlined,
              size: 20,
              color: isTask ? cs.primary : cs.tertiary,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                item.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small icon + number pill used to show descendant task counts.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
