import 'package:flutter/material.dart';

import '../../../../core/format/created_at.dart';
import '../../data/note_model.dart';
import '../notes_controller.dart';
import '../widgets/item_visuals.dart';
import '../widgets/note_page.dart';

/// The right column of the wide layout: the selected item's title, date, and
/// full note editor (reusing [NotePage], which autosaves via the controller).
/// Shows a quiet placeholder when nothing is selected.
class NotePane extends StatelessWidget {
  const NotePane({
    super.key,
    required this.controller,
    required this.selectedId,
  });

  final NotesController controller;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Item? item;
    final id = selectedId;
    if (id != null) {
      for (final i in controller.items) {
        if (i.id == id) {
          item = i;
          break;
        }
      }
    }

    if (item == null) {
      return Center(
        child: Icon(
          Icons.notes_rounded,
          size: 40,
          color: cs.onSurface.withValues(alpha: 0.15),
        ),
      );
    }

    final isTask = item.type == ItemType.task;
    final accent = item.color != null
        ? Color(item.color!)
        : (isTask ? cs.primary : cs.tertiary);
    final hasVisual = item.icon != null || item.color != null;
    final titleText = Text(
      item.content,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: cs.onSurface,
        decoration: isTask && item.isDone ? TextDecoration.lineThrough : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasVisual)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        itemIconData(item.icon) ??
                            (isTask
                                ? Icons.check_circle_outline_rounded
                                : Icons.sticky_note_2_outlined),
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: titleText),
                  ],
                )
              else
                titleText,
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: cs.onSurface.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    formatCreatedAt(
                      item.createdAt,
                      Localizations.localeOf(context),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: NotePage(
            key: ValueKey('note_${item.id}'),
            text: item.body ?? '',
            onChanged: (v) => controller.setBody(id!, v),
          ),
        ),
      ],
    );
  }
}
