import 'package:flutter/material.dart';

import '../../../../core/format/created_at.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/note_model.dart';
import '../notes_controller.dart';
import '../widgets/item_actions_sheet.dart';
import '../widgets/item_visuals.dart';

/// The Archive screen: everything the user has archived, restorable or
/// permanently deletable. Archived items live outside the controller's active
/// board, so this screen loads them on demand and refreshes whenever the
/// controller changes (e.g. after a restore or delete).
///
/// Archiving cascades to a subtree, so we only list the *archive roots* — an
/// archived item whose parent isn't itself archived. Restoring or deleting a
/// root carries its whole subtree with it.
class ArchiveView extends StatefulWidget {
  const ArchiveView({super.key, required this.controller});

  final NotesController controller;

  @override
  State<ArchiveView> createState() => _ArchiveViewState();
}

class _ArchiveViewState extends State<ArchiveView> {
  late Future<List<Item>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadArchived();
    widget.controller.addListener(_reload);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final future = widget.controller.loadArchived();
    setState(() {
      _future = future;
    });
  }

  /// Keeps only the archive roots: an archived item whose parent is not itself
  /// archived (so each subtree shows once, by the item the user archived).
  List<Item> _roots(List<Item> archived) {
    final ids = {for (final i in archived) i.id};
    return archived
        .where((i) => i.parentId == null || !ids.contains(i.parentId))
        .toList();
  }

  Future<void> _restore(Item item) => widget.controller.unarchiveItem(item.id);

  Future<void> _delete(Item item) async {
    final ok = await confirmDelete(context);
    if (ok) await widget.controller.deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          l.archive,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: FutureBuilder<List<Item>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final roots = _roots(snapshot.data!);
          if (roots.isEmpty) return _empty(context, l, cs);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  for (final item in roots)
                    _ArchivedRow(
                      item: item,
                      onRestore: () => _restore(item),
                      onDelete: () => _delete(item),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, AppLocalizations l, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.archive_outlined,
              size: 36,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              l.archiveEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One archived item: icon, title, archived date, with restore + delete buttons.
class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({
    required this.item,
    required this.onRestore,
    required this.onDelete,
  });

  final Item item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final isTask = item.type == ItemType.task;
    final accent = item.color != null
        ? Color(item.color!)
        : (isTask ? cs.primary : cs.tertiary);
    final icon =
        itemIconData(item.icon) ??
        (isTask
            ? Icons.check_circle_outline_rounded
            : Icons.sticky_note_2_outlined);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.archivedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatCreatedAt(
                          item.archivedAt!,
                          Localizations.localeOf(context),
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.unarchive_outlined),
                tooltip: l.restore,
                onPressed: onRestore,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: cs.error,
                tooltip: l.delete,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
