import 'package:flutter/material.dart';

import '../../../../core/format/created_at.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/note_model.dart';
import 'item_visuals.dart';
import 'reminder_help.dart';

/// A flat, tappable row for one item. Tapping opens the item's own screen;
/// long-press starts a drag (to nest or reorder — the drop target decides);
/// swipe right to rename, swipe left to delete. The subtitle shows how many
/// descendant tasks are left.
///
/// Drop handling lives in the surrounding `ReorderableItem`; this widget is only
/// the drag source + tile. [nestHighlight] draws the accent border when it's the
/// hovered nest target.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    required this.completedTasks,
    required this.uncompletedTasks,
    required this.onTap,
    required this.onToggleDone,
    required this.onRename,
    required this.onConfirmDelete,
    required this.onDelete,
    this.nestHighlight = false,
    this.reminderState = ReminderBadgeState.ok,
    this.onReminderWarningTap,
    this.onDragStarted,
    this.onDragEnded,
  });

  final Item item;
  final int completedTasks;
  final int uncompletedTasks;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  /// Swipe right → rename (opens a dialog; the row snaps back).
  final Future<void> Function() onRename;

  /// Swipe left → confirm deletion (returns true to proceed).
  final Future<bool> Function() onConfirmDelete;

  /// Performs the actual deletion once the swipe is confirmed.
  final VoidCallback onDelete;

  /// Highlights the tile while it's the hovered nest target.
  final bool nestHighlight;

  /// Delivery state of this item's reminder badge (ok / askable / blocked).
  final ReminderBadgeState reminderState;

  /// Tapped when the badge is in a warning state (askable → allow; blocked →
  /// show how to re-enable).
  final VoidCallback? onReminderWarningTap;

  /// Fired when this row's long-press drag begins / ends, so the screen can
  /// turn the add button into a trash drop target.
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Item>(
      data: item,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnded?.call(),
      // Carry the tile centered under the finger.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: _DragFeedback(item: item),
      ),
      childWhenDragging: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Opacity(opacity: 0.4, child: _tile(context, false)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Dismissible(
            key: ValueKey('row_${item.id}'),
            background: _swipeAction(
              context,
              icon: Icons.edit_outlined,
              color: Theme.of(context).colorScheme.primary,
              alignment: Alignment.centerLeft,
            ),
            secondaryBackground: _swipeAction(
              context,
              icon: Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              alignment: Alignment.centerRight,
            ),
            confirmDismiss: (dir) async {
              if (dir == DismissDirection.endToStart) {
                return onConfirmDelete(); // swipe left -> delete
              }
              await onRename(); // swipe right -> rename, snap back
              return false;
            },
            onDismissed: (_) => onDelete(),
            child: _tile(context, nestHighlight),
          ),
        ),
      ),
    );
  }

  /// The coloured action panel revealed behind the tile while swiping.
  Widget _swipeAction(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required Alignment alignment,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Color.alphaBlend(
        color.withValues(alpha: 0.16),
        Theme.of(context).colorScheme.surface,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _tile(BuildContext context, bool highlighted) {
    final cs = Theme.of(context).colorScheme;
    final isTask = item.type == ItemType.task;
    final isDone = isTask && item.isDone;

    final accent = item.color != null
        ? Color(item.color!)
        : (isTask ? cs.primary : cs.tertiary);
    // Notes can carry a custom glyph; tasks keep the checkbox affordance.
    final noteIcon = itemIconData(item.icon) ?? Icons.sticky_note_2_outlined;
    // Composite over the surface so the tile is opaque — otherwise the swipe
    // action panel behind it would bleed through the translucent tile.
    final tint = highlighted
        ? cs.primary.withValues(alpha: 0.18)
        : cs.surfaceContainerHighest.withValues(alpha: isTask ? 0.5 : 0.3);
    final tileColor = Color.alphaBlend(tint, cs.surface);

    return Material(
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
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
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
                        : noteIcon,
                    size: isTask ? 22 : 19,
                    color: accent.withValues(
                      alpha: isTask && !isDone ? 0.7 : 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Title, with the task progress (1/12) as a quiet subtitle.
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
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (uncompletedTasks > 0) ...[
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$uncompletedTasks ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF7043), // deep orange
                              ),
                            ),
                            TextSpan(
                              text: AppLocalizations.of(
                                context,
                              ).tasksLeft(uncompletedTasks),
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Right side: the created date, with a reminder badge above it
              // when the item has a reminder set.
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.reminderAt != null) ...[
                    _reminderBadge(context, accent),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    formatCreatedAt(
                      item.createdAt,
                      Localizations.localeOf(context),
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.2,
                      color: cs.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The reminder badge on the right of the tile:
  /// - ok → accent time
  /// - askable → amber, "tap to allow"
  /// - blocked → red strike-through, "tap to fix"
  Widget _reminderBadge(BuildContext context, Color accent) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final time = formatCreatedAt(
      item.reminderAt!,
      Localizations.localeOf(context),
    );

    if (reminderState == ReminderBadgeState.ok) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_outlined, size: 11, color: accent),
          const SizedBox(width: 3),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      );
    }

    final blocked = reminderState == ReminderBadgeState.blocked;
    final color = blocked ? cs.error : const Color(0xFFFFA000); // red / amber
    final message = blocked ? l.remindersBlocked : l.remindersNeedPermission;

    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onReminderWarningTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              blocked
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_active_outlined,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                decoration: blocked ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
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
