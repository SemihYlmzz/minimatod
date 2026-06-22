import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/note_model.dart';
import '../notes_controller.dart';
import '../search/item_search_delegate.dart';
import '../widgets/add_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_actions_sheet.dart';
import '../widgets/item_row.dart';
import '../widgets/path_title.dart';
import '../widgets/reminder_help.dart';
import '../widgets/reorderable_item.dart';
import '../widgets/section_divider.dart';

/// The middle column of the wide layout: the breadcrumb of the current
/// selection, an add button, and the selected item's children (notes above
/// tasks). Tapping a child selects it (drills in); the row widgets and actions
/// are the same ones the phone UI uses.
class ItemsPane extends StatefulWidget {
  const ItemsPane({
    super.key,
    required this.controller,
    required this.selectedId,
    required this.query,
    required this.onSelect,
    required this.onClearSearch,
    required this.onAdd,
  });

  final NotesController controller;
  final String? selectedId;
  final String query;
  final ValueChanged<String?> onSelect;
  final VoidCallback onClearSearch;
  final VoidCallback onAdd;

  @override
  State<ItemsPane> createState() => _ItemsPaneState();
}

class _ItemsPaneState extends State<ItemsPane> {
  bool _dragging = false;

  NotesController get _controller => widget.controller;

  Future<void> _confirmDeleteItem(Item item) async {
    final ok = await confirmDelete(context);
    if (ok) await _controller.deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isNotEmpty) return _buildSearchResults(context);

    final l = AppLocalizations.of(context);
    final items = _controller.childrenOf(widget.selectedId);
    final notes = items.where((i) => i.type == ItemType.note).toList();
    final tasks = items.where((i) => i.type == ItemType.task).toList();

    return Column(
      children: [
        // Breadcrumb only once drilled in — at Home the sidebar already shows
        // "Home", so we don't repeat it here.
        if (widget.selectedId != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: PathTitle(
              path: _controller.pathTo(widget.selectedId!),
              onCrumbTap: widget.onSelect,
              onCrumbDrop: (id, dragged) => _controller.reparent(dragged, id),
            ),
          ),
          const Divider(height: 1, thickness: 1),
        ] else
          const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? const EmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                  children: [
                    for (final item in notes) _row(context, item, notes),
                    if (notes.isNotEmpty && tasks.isNotEmpty)
                      SectionDivider(label: l.tasks),
                    for (final item in tasks) _row(context, item, tasks),
                  ],
                ),
        ),
        AddBar(
          onAdd: widget.onAdd,
          dragActive: _dragging,
          onDeleteDrop: _confirmDeleteItem,
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final results = searchItems(_controller, widget.query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '“${widget.query.trim()}”',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: l.cancel,
                onPressed: widget.onClearSearch,
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    l.searchEmpty,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                  children: [
                    for (final item in results) _itemRow(context, item),
                  ],
                ),
        ),
      ],
    );
  }

  /// A row wrapped for nest + reorder drops within its [group].
  Widget _row(BuildContext context, Item item, List<Item> group) {
    return ReorderableItem(
      controller: _controller,
      item: item,
      parentId: widget.selectedId,
      group: group,
      rowBuilder: (nestHighlight) =>
          _itemRow(context, item, nestHighlight: nestHighlight),
    );
  }

  Widget _itemRow(
    BuildContext context,
    Item item, {
    bool nestHighlight = false,
  }) {
    final counts = _controller.descendantTaskCounts(item.id);
    return ItemRow(
      item: item,
      completedTasks: counts.completed,
      uncompletedTasks: counts.uncompleted,
      nestHighlight: nestHighlight,
      reminderState: reminderBadgeState(_controller),
      onReminderWarningTap: () =>
          handleReminderWarningTap(context, _controller),
      onDragStarted: () => setState(() => _dragging = true),
      onDragEnded: () => setState(() => _dragging = false),
      onTap: () => widget.onSelect(item.id),
      onToggleDone: () => _controller.toggleDone(item),
      onRename: () async {
        final name = await showRenameDialog(context, item.content);
        if (name != null && name.isNotEmpty) {
          await _controller.editContent(item, name);
        }
      },
      onConfirmDelete: () => confirmDelete(context),
      onDelete: () => _controller.deleteItem(item.id),
    );
  }
}
