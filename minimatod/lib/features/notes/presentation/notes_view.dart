import 'package:flutter/material.dart';

import '../../../core/settings/app_settings_controller.dart';
import '../../../core/widgets/dismiss_keyboard.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_view.dart';
import '../data/note_model.dart';
import 'create_item_page.dart';
import 'notes_controller.dart';
import 'search/item_search_delegate.dart';
import 'widgets/add_bar.dart';
import 'widgets/breadcrumb_bar.dart';
import 'widgets/empty_state.dart';
import 'widgets/item_actions_sheet.dart';
import 'widgets/item_row.dart';
import 'widgets/section_divider.dart';

/// A single level of the note/task tree.
///
/// Recursive: the root screen has `parent == null` and lists root items;
/// tapping a row pushes another [NotesView] scoped to that item, showing its
/// children. New items added here are nested under [parent].
class NotesView extends StatefulWidget {
  const NotesView({
    super.key,
    required this.controller,
    required this.settings,
    this.parent,
  });

  final NotesController controller;
  final AppSettingsController settings;
  final Item? parent;

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  // Notes are grouped above tasks in the list.
  static const bool _notesFirst = true;

  /// Opens the create page; on return, adds the item under the current level.
  Future<void> _openCreate() async {
    final result = await Navigator.of(context).push<CreateItemResult>(
      MaterialPageRoute<CreateItemResult>(
        builder: (_) => const CreateItemPage(),
      ),
    );
    if (result == null) return;
    await widget.controller.addItem(
      content: result.content,
      type: result.type,
      parentId: widget.parent?.id,
    );
  }

  void _openItem(Item item) {
    // Drop focus first so the keyboard doesn't reference this route's widgets
    // across the navigation transition.
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(arguments: item.id),
        builder: (_) => NotesView(
          controller: widget.controller,
          settings: widget.settings,
          parent: item,
        ),
      ),
    );
  }

  /// Navigates to [item] from anywhere by rebuilding the route stack so the
  /// breadcrumb stays consistent: pop to root, then push the full ancestor
  /// chain down to the item.
  void _navigateToItem(Item item) {
    FocusManager.instance.primaryFocus?.unfocus();
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    for (final ancestor in widget.controller.pathTo(item.id)) {
      nav.push(
        MaterialPageRoute<void>(
          settings: RouteSettings(arguments: ancestor.id),
          builder: (_) => NotesView(
            controller: widget.controller,
            settings: widget.settings,
            parent: ancestor,
          ),
        ),
      );
    }
  }

  void _onCrumbTap(String? id) {
    FocusManager.instance.primaryFocus?.unfocus();
    final nav = Navigator.of(context);
    if (id == null) {
      nav.popUntil((r) => r.isFirst);
    } else {
      nav.popUntil((r) => r.isFirst || r.settings.arguments == id);
    }
  }

  /// Dropping a dragged item onto a breadcrumb chip re-parents it up the tree
  /// ([id] null = move to the root level).
  void _onCrumbDrop(String? id, Item dragged) {
    widget.controller.reparent(dragged, id);
  }

  Future<void> _openSearch() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showSearch<Item?>(
      context: context,
      delegate: ItemSearchDelegate(
        widget.controller,
        AppLocalizations.of(context),
      ),
    );
    if (selected != null && mounted) _navigateToItem(selected);
  }

  Future<void> _onItemMenu(Item item, {bool isCurrent = false}) async {
    final action = await showItemActionsSheet(context, item);
    if (action == null || !mounted) return;
    switch (action) {
      case ItemAction.rename:
        final name = await showRenameDialog(context, item.content);
        if (name != null && name.isNotEmpty) {
          await widget.controller.editContent(item, name);
        }
      case ItemAction.delete:
        if (!mounted) return;
        final ok = await confirmDelete(context);
        if (!ok) return;
        await widget.controller.deleteItem(item.id);
        if (isCurrent && mounted) Navigator.of(context).pop();
    }
  }

  /// Builds the list, grouping notes above tasks, split by a divider.
  Widget _buildList(List<Item> items) {
    final l = AppLocalizations.of(context);
    final notes = items.where((i) => i.type == ItemType.note).toList();
    final tasks = items.where((i) => i.type == ItemType.task).toList();

    final first = _notesFirst ? notes : tasks;
    final second = _notesFirst ? tasks : notes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        for (final item in first) _row(item),
        if (first.isNotEmpty && second.isNotEmpty)
          SectionDivider(label: _notesFirst ? l.tasks : l.notes),
        for (final item in second) _row(item),
      ],
    );
  }

  Widget _row(Item item) {
    final counts = widget.controller.descendantTaskCounts(item.id);
    return ItemRow(
      item: item,
      completedTasks: counts.completed,
      uncompletedTasks: counts.uncompleted,
      canAcceptDrop: (dragged) =>
          dragged.id != item.id &&
          !widget.controller.isDescendant(item.id, dragged.id),
      onAcceptDrop: (dragged) => widget.controller.reparent(dragged, item.id),
      onTap: () => _openItem(item),
      onToggleDone: () => widget.controller.toggleDone(item),
      onMenu: () => _onItemMenu(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final isRoot = widget.parent == null;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          isRoot ? l.appTitle : widget.parent!.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        // Root: Settings on the left. Non-root: default back button.
        leading: isRoot
            ? IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: l.settings,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsView(settings: widget.settings),
                  ),
                ),
              )
            : null,
        bottom: isRoot
            ? null
            : BreadcrumbBar(
                path: widget.controller.pathTo(widget.parent!.id),
                onCrumbTap: _onCrumbTap,
                onCrumbDrop: _onCrumbDrop,
              ),
        actions: [
          if (isRoot)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: l.searchHint,
              onPressed: _openSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () => _onItemMenu(widget.parent!, isCurrent: true),
            ),
        ],
      ),
      body: DismissKeyboard(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final items = widget.controller.childrenOf(widget.parent?.id);
            if (items.isEmpty) return const EmptyState();
            return _buildList(items);
          },
        ),
      ),
      bottomNavigationBar: AddBar(onAdd: _openCreate),
    );
  }
}
