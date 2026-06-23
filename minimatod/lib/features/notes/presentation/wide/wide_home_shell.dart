import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/widgets/dismiss_keyboard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/presentation/settings_view.dart';
import '../../data/note_model.dart';
import '../archive/archive_view.dart';
import '../composer/create_item_sheet.dart';
import '../notes_controller.dart';
import '../search/item_search_delegate.dart';
import '../widgets/item_actions_sheet.dart';
import 'items_pane.dart';
import 'note_pane.dart';
import 'sidebar.dart';

/// The wide (iPad / desktop) home: a collapsible sidebar of top-level items
/// plus the selected item's children (middle) and its note (right), all at once.
///
/// Selection-driven (not Navigator-pushed): [_selectedId] is the open item, null
/// = nothing selected (Home). Shares [NotesController] and the same row/note
/// widgets as the phone UI — only the navigation model differs.
class WideHomeShell extends StatefulWidget {
  const WideHomeShell({
    super.key,
    required this.controller,
    required this.settings,
  });

  final NotesController controller;
  final AppSettingsController settings;

  @override
  State<WideHomeShell> createState() => _WideHomeShellState();
}

class _WideHomeShellState extends State<WideHomeShell> {
  String? _selectedId;
  bool _sidebarCollapsed = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _select(String? id) => setState(() {
    _selectedId = id;
    if (_query.isNotEmpty) {
      _query = '';
      _searchCtrl.clear();
    }
  });

  void _onQuery(String v) => setState(() => _query = v);

  void _clearSearch() => setState(() {
    _query = '';
    _searchCtrl.clear();
  });

  void _toggleSidebar() =>
      setState(() => _sidebarCollapsed = !_sidebarCollapsed);

  Future<void> _openCreate() async {
    final result = await showCreateItemSheet(
      context,
      notifications: widget.controller.reminders?.notifications,
      audio: widget.controller.audio,
    );
    if (result == null) return;
    await widget.controller.addItem(
      content: result.content,
      type: result.type,
      icon: result.icon,
      color: result.color,
      reminderAt: result.reminderAt,
      parentId: _selectedId,
      recording: result.audio,
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsView(
          settings: widget.settings,
          controller: widget.controller,
        ),
      ),
    );
  }

  void _openArchive() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArchiveView(controller: widget.controller),
      ),
    );
  }

  /// The selected item's overflow menu (the wide-layout parallel to the phone
  /// detail ⋯): edit, archive, or delete. Archiving/deleting clears the now-gone
  /// selection back to Home.
  Future<void> _onItemMenu(Item item) async {
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
          notifications: widget.controller.reminders?.notifications,
          audio: widget.controller.audio,
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
        final rec = result.audio;
        if (rec != null) {
          await widget.controller.audio?.attach(live.id, rec);
        } else if (result.removeAudio) {
          await widget.controller.audio?.remove(live.id);
        }
      case ItemAction.archive:
        await widget.controller.archiveItem(live.id);
        _select(null);
      case ItemAction.delete:
        if (!mounted) return;
        final ok = await confirmDelete(context);
        if (!ok) return;
        await widget.controller.deleteItem(live.id);
        _select(null);
    }
  }

  Future<void> _openSearch() async {
    final selected = await showSearch<Item?>(
      context: context,
      delegate: ItemSearchDelegate(
        widget.controller,
        AppLocalizations.of(context),
      ),
    );
    if (selected != null && mounted) _select(selected.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: DismissKeyboard(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              widget.controller,
              widget.controller.audio,
            ]),
            builder: (context, _) {
              // Drop a stale selection if the item was deleted.
              final id = _selectedId;
              final exists =
                  id == null || widget.controller.items.any((i) => i.id == id);
              final selectedId = exists ? id : null;

              // Below this width (e.g. iPad portrait) keep the sidebar as a rail
              // so the items + note columns aren't crowded.
              final canExpandSidebar = MediaQuery.sizeOf(context).width >= 900;
              final collapsed = _sidebarCollapsed || !canExpandSidebar;

              return Row(
                children: [
                  Sidebar(
                    controller: widget.controller,
                    selectedId: selectedId,
                    collapsed: collapsed,
                    onToggle: _toggleSidebar,
                    showToggle: canExpandSidebar,
                    searchController: _searchCtrl,
                    onQueryChanged: _onQuery,
                    onSelectItem: _select,
                    onHome: () => _select(null),
                    onSearch: _openSearch,
                    onSettings: _openSettings,
                    onArchive: _openArchive,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    flex: 3,
                    child: ItemsPane(
                      controller: widget.controller,
                      selectedId: selectedId,
                      query: _query,
                      onSelect: _select,
                      onClearSearch: _clearSearch,
                      onAdd: _openCreate,
                      onItemMenu: _onItemMenu,
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    flex: 4,
                    child: NotePane(
                      controller: widget.controller,
                      selectedId: selectedId,
                      onMenu: _onItemMenu,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
