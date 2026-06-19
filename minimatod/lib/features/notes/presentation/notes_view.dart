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
import 'widgets/detail_tabs.dart';
import 'widgets/empty_state.dart';
import 'widgets/item_actions_sheet.dart';
import 'widgets/item_row.dart';
import 'widgets/note_page.dart';
import 'widgets/path_title.dart';
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

  // Detail pages are a 2-page swipe: [0] children list, [1] full note editor.
  final PageController _pageController = PageController();
  int _page = 0;

  // Focus of the note editor — drives the "Done" button in the AppBar.
  final FocusNode _noteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _goToPage(int i) {
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

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

  /// Navigates to [item] from anywhere by rebuilding the route stack: pop to
  /// root, then push the full ancestor chain down to the item (so back goes up
  /// one level at a time).
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

  void _onCrumbTap(String? id) {
    FocusManager.instance.primaryFocus?.unfocus();
    final nav = Navigator.of(context);
    if (id == null) {
      nav.popUntil((r) => r.isFirst);
    } else {
      nav.popUntil((r) => r.isFirst || r.settings.arguments == id);
    }
  }

  /// Dropping a dragged item onto a path crumb re-parents it there (id null =
  /// move to the root level) — the quick way to move an item up/out.
  void _onCrumbDrop(String? id, Item dragged) {
    widget.controller.reparent(dragged, id);
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

  /// Builds the children list, grouping notes above tasks, split by a divider.
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

  /// The children-list page (left). Shows a gentle hint when empty so the page
  /// stays swipeable to the note on the right.
  Widget _listPage(List<Item> items) {
    if (items.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      final l = AppLocalizations.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded,
                  size: 30, color: cs.onSurface.withValues(alpha: 0.25)),
              const SizedBox(height: 8),
              Text(
                l.emptyChildrenHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _buildList(items);
  }

  /// The detail body: a horizontal swipe between the children list and the
  /// full note editor for [parent]. (The page indicator lives in the AppBar.)
  Widget _buildDetailPager(Item parent, List<Item> items) {
    return PageView(
      controller: _pageController,
      onPageChanged: (i) {
        // Leaving the note → drop focus so it autosaves and the keyboard hides.
        if (i != 1) _noteFocus.unfocus();
        setState(() => _page = i);
      },
      children: [
        _listPage(items),
        NotePage(
          key: ValueKey('note_${parent.id}'),
          focusNode: _noteFocus,
          text: parent.body ?? '',
          onChanged: (v) => widget.controller.setBody(parent.id, v),
        ),
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
      onRename: () async {
        final name = await showRenameDialog(context, item.content);
        if (name != null && name.isNotEmpty) {
          await widget.controller.editContent(item, name);
        }
      },
      onConfirmDelete: () => confirmDelete(context),
      onDelete: () => widget.controller.deleteItem(item.id),
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
        // Root → app name (centred). Detail → the scrollable path, which also
        // accepts dropped items to move them up to Home/an ancestor.
        title: isRoot
            ? Text(
                l.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              )
            : PathTitle(
                path: widget.controller.pathTo(widget.parent!.id),
                onCrumbTap: _onCrumbTap,
                onCrumbDrop: _onCrumbDrop,
              ),
        centerTitle: isRoot,
        titleSpacing: 0,
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
        bottom: isRoot ? null : DetailTabs(index: _page, onTap: _goToPage),
        actions: [
          if (isRoot)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: l.searchHint,
              onPressed: _openSearch,
            )
          else if (_noteFocus.hasFocus)
            // Typing in the note → a Done button to dismiss the keyboard.
            TextButton(
              onPressed: () => _noteFocus.unfocus(),
              child: Text(
                l.done,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
            if (isRoot) {
              return items.isEmpty ? const EmptyState() : _buildList(items);
            }
            // Detail page → swipe between children list and the note. Use the
            // live item (with the latest saved body), falling back to the route
            // snapshot if it's mid-reload.
            final id = widget.parent!.id;
            var live = widget.parent!;
            for (final i in widget.controller.items) {
              if (i.id == id) {
                live = i;
                break;
              }
            }
            return _buildDetailPager(live, items);
          },
        ),
      ),
      // The add button belongs to the list page; hide it on the note page.
      bottomNavigationBar:
          (isRoot || _page == 0) ? AddBar(onAdd: _openCreate) : null,
    );
  }
}
