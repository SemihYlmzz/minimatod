import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/note_model.dart';
import '../notes_controller.dart';

/// The wide-layout left panel: app title, pinned Home / Search / Settings, then
/// the top-level items as quick navigation. Tapping an item selects it; the
/// crumb of the current selection is highlighted up its root ancestor.
///
/// Collapses to a slim icon rail via [onToggle]; the width animates between the
/// two states.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.controller,
    required this.selectedId,
    required this.collapsed,
    required this.onToggle,
    this.showToggle = true,
    required this.searchController,
    required this.onQueryChanged,
    required this.onSelectItem,
    required this.onHome,
    required this.onSearch,
    required this.onSettings,
  });

  final NotesController controller;
  final String? selectedId;
  final bool collapsed;
  final VoidCallback onToggle;

  /// Whether to show the collapse/expand button. Hidden when the layout forces
  /// the rail (e.g. iPad portrait), where expanding would crowd the columns.
  final bool showToggle;

  /// Inline search field (expanded state); [onSearch] opens the modal search
  /// when collapsed.
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelectItem;
  final VoidCallback onHome;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  static const double _expandedWidth = 264;
  static const double _collapsedWidth = 72;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final roots = controller.childrenOf(null);

    // The root ancestor currently in view, so its sidebar tile reads as active.
    String? activeRootId;
    if (selectedId != null) {
      final path = controller.pathTo(selectedId!);
      if (path.isNotEmpty) activeRootId = path.first.id;
    }

    final targetWidth = collapsed ? _collapsedWidth : _expandedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: targetWidth,
      color: cs.surface,
      // Lay the content out at its final width and clip the overflow while the
      // container animates — otherwise the row contents reflow and flash an
      // overflow during the expand.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: targetWidth,
          maxWidth: targetWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, l),
              if (collapsed)
                _NavTile(
                  icon: Icons.search_rounded,
                  label: l.searchHint,
                  collapsed: true,
                  selected: false,
                  onTap: onSearch,
                )
              else
                _searchField(context, l),
              _NavTile(
                icon: Icons.home_rounded,
                label: l.home,
                collapsed: collapsed,
                selected: selectedId == null,
                onTap: onHome,
              ),
              _NavTile(
                icon: Icons.settings_outlined,
                label: l.settings,
                collapsed: collapsed,
                selected: false,
                onTap: onSettings,
              ),
              const Divider(height: 16, indent: 12, endIndent: 12),
              Expanded(
                child: roots.isEmpty
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          for (final item in roots)
                            _NavTile(
                              icon: item.type == ItemType.task
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.sticky_note_2_outlined,
                              label: item.content,
                              collapsed: collapsed,
                              selected: item.id == activeRootId,
                              onTap: () => onSelectItem(item.id),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context, AppLocalizations l) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: searchController,
        onChanged: onQueryChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: l.searchHint,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          filled: true,
          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l) {
    final toggle = IconButton(
      icon: Icon(collapsed ? Icons.menu_rounded : Icons.menu_open_rounded),
      onPressed: onToggle,
    );
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Center(child: showToggle ? toggle : const SizedBox(height: 48)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.appTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          toggle,
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurface.withValues(alpha: 0.75);
    final bg = selected
        ? cs.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    final child = collapsed
        ? Tooltip(
            message: label,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Icon(icon, size: 22, color: color),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}
