import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/note_model.dart';

/// The per-item actions surfaced from the trailing ⋯ button. Editing (title,
/// type, icon, colour, reminder) all happens in the composer sheet, so a single
/// "Edit" entry covers what used to be rename + convert.
enum ItemAction { edit, archive, delete }

/// Shows the long-press / overflow actions sheet for [item]. Returns the chosen
/// [ItemAction], or null if dismissed.
Future<ItemAction?> showItemActionsSheet(BuildContext context, Item item) {
  return showModalBottomSheet<ItemAction>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) {
      final l = AppLocalizations.of(context);
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionTile(
              icon: Icons.tune_rounded,
              label: l.edit,
              onTap: () => Navigator.of(context).pop(ItemAction.edit),
            ),
            _ActionTile(
              icon: Icons.archive_outlined,
              label: l.archiveAction,
              onTap: () => Navigator.of(context).pop(ItemAction.archive),
            ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: l.delete,
              destructive: true,
              onTap: () => Navigator.of(context).pop(ItemAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// A rename dialog prefilled with [initial]. Returns the trimmed new text, or
/// null if cancelled / unchanged.
Future<String?> showRenameDialog(BuildContext context, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(l.renameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      );
    },
  );
}

/// A confirmation dialog before deleting an item (and its subtree). Returns true
/// to proceed.
Future<bool> confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(l.deleteConfirmTitle),
        content: Text(l.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.delete),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = destructive ? cs.error : cs.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
