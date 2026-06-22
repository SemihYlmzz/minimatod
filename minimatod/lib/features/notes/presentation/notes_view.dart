import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../../core/navigation/route_stack.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/widgets/dismiss_keyboard.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_view.dart';
import '../data/note_model.dart';
import 'create_item_sheet.dart';
import 'notes_controller.dart';
import 'search/item_search_delegate.dart';
import 'widgets/add_bar.dart';
import 'widgets/detail_tabs.dart';
import 'widgets/empty_state.dart';
import 'widgets/item_actions_sheet.dart';
import 'widgets/item_row.dart';
import 'widgets/note_page.dart';
import 'widgets/reminder_help.dart';
import 'widgets/path_title.dart';
import 'widgets/reorderable_item.dart';
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

  // True while a row is being dragged — turns the add button into a trash zone.
  bool _dragging = false;

  Future<void> _confirmDeleteItem(Item item) async {
    final ok = await confirmDelete(context);
    if (ok) await widget.controller.deleteItem(item.id);
  }

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
    final result = await showCreateItemSheet(
      context,
      notifications: widget.controller.notifications,
    );
    if (result == null) return;
    await widget.controller.addItem(
      content: result.content,
      type: result.type,
      icon: result.icon,
      color: result.color,
      reminderAt: result.reminderAt,
      parentId: widget.parent?.id,
    );
  }

  /// Navigates to [item] from anywhere by rebuilding the route stack: pop to
  /// root, then push the full ancestor chain down to the item (so back goes up
  /// one level at a time).
  void _navigateToItem(Item item) {
    FocusManager.instance.primaryFocus?.unfocus();
    final nav = Navigator.of(context);
    routeStackObserver.jumpTo(nav, (r) => r.isFirst);
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
    // Remove the in-between pages instantly so their container-transform reverse
    // animations don't overlap into a broken-looking blur.
    routeStackObserver.jumpTo(
      Navigator.of(context),
      (r) => id == null ? r.isFirst : (r.isFirst || r.settings.arguments == id),
      animate: true,
    );
  }

  /// Dropping a dragged item onto a path crumb re-parents it there (id null =
  /// move to the root level) — the quick way to move an item up/out.
  void _onCrumbDrop(String? id, Item dragged) {
    widget.controller.reparent(dragged, id);
  }

  Future<void> _onItemMenu(Item item, {bool isCurrent = false}) async {
    // Use the live item so the sheet reflects the current values, not the stale
    // snapshot from when this page was opened.
    final live = widget.controller.items.firstWhere(
      (i) => i.id == item.id,
      orElse: () => item,
    );
    final action = await showItemActionsSheet(context, live);
    if (action == null || !mounted) return;
    switch (action) {
      case ItemAction.edit:
        final result = await showCreateItemSheet(
          context,
          initial: live,
          notifications: widget.controller.notifications,
        );
        if (result == null) return;
        await widget.controller.updateItemMeta(
          live,
          content: result.content,
          type: result.type,
          icon: result.icon,
          color: result.color,
          reminderAt: result.reminderAt,
        );
      case ItemAction.archive:
        await widget.controller.archiveItem(live.id);
        if (isCurrent && mounted) Navigator.of(context).pop();
      case ItemAction.delete:
        if (!mounted) return;
        final ok = await confirmDelete(context);
        if (!ok) return;
        await widget.controller.deleteItem(live.id);
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            for (final item in first) _row(item, first),
            if (first.isNotEmpty && second.isNotEmpty)
              SectionDivider(label: _notesFirst ? l.tasks : l.notes),
            for (final item in second) _row(item, second),
          ],
        ),
      ),
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
              Icon(
                Icons.add_rounded,
                size: 30,
                color: cs.onSurface.withValues(alpha: 0.25),
              ),
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

  Widget _row(Item item, List<Item> group) {
    final counts = widget.controller.descendantTaskCounts(item.id);
    final cs = Theme.of(context).colorScheme;
    return ReorderableItem(
      controller: widget.controller,
      item: item,
      parentId: widget.parent?.id,
      group: group,
      // Tapping morphs the tile into its detail page (container transform); the
      // opened page adds an edge swipe-back (see [_EdgeSwipeBack]).
      rowBuilder: (nestHighlight) => OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 360),
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: cs.surface,
        middleColor: cs.surface,
        closedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        routeSettings: RouteSettings(arguments: item.id),
        closedBuilder: (context, open) => ItemRow(
          item: item,
          completedTasks: counts.completed,
          uncompletedTasks: counts.uncompleted,
          nestHighlight: nestHighlight,
          reminderState: reminderBadgeState(widget.controller),
          onReminderWarningTap: () =>
              handleReminderWarningTap(context, widget.controller),
          onDragStarted: () => setState(() => _dragging = true),
          onDragEnded: () => setState(() => _dragging = false),
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            open();
          },
          onToggleDone: () => widget.controller.toggleDone(item),
          onRename: () async {
            final name = await showRenameDialog(context, item.content);
            if (name != null && name.isNotEmpty) {
              await widget.controller.editContent(item, name);
            }
          },
          onConfirmDelete: () => confirmDelete(context),
          onDelete: () => widget.controller.deleteItem(item.id),
        ),
        openBuilder: (context, close) => NotesView(
          controller: widget.controller,
          settings: widget.settings,
          parent: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final isRoot = widget.parent == null;

    final scaffold = Scaffold(
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
                    builder: (_) => SettingsView(
                      settings: widget.settings,
                      controller: widget.controller,
                    ),
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
      bottomNavigationBar: (isRoot || _page == 0)
          ? AddBar(
              onAdd: _openCreate,
              dragActive: _dragging,
              onDeleteDrop: _confirmDeleteItem,
            )
          : null,
    );

    // Root has nothing to pop to; detail pages get a left-edge swipe-back that
    // pops with the container transform reversing.
    if (isRoot) return scaffold;
    return _EdgeSwipeBack(
      onBack: () => Navigator.maybePop(context),
      child: scaffold,
    );
  }
}

/// Wraps a page with a thin left-edge horizontal-drag detector that invokes
/// [onBack] on a rightward swipe — restoring "swipe to go back" on a route
/// (like [OpenContainer]'s) that has no built-in back gesture. The page doesn't
/// track the finger; the gesture simply triggers the route's normal reverse
/// (here, the container-transform morph).
class _EdgeSwipeBack extends StatefulWidget {
  const _EdgeSwipeBack({required this.child, required this.onBack});

  final Widget child;
  final VoidCallback onBack;

  @override
  State<_EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<_EdgeSwipeBack> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 22,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _dx = 0,
            onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
            onHorizontalDragEnd: (d) {
              final flung = (d.primaryVelocity ?? 0) > 250;
              if (flung || _dx > 60) widget.onBack();
              _dx = 0;
            },
          ),
        ),
      ],
    );
  }
}
