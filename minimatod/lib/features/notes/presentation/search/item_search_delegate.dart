import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/note_model.dart';
import '../notes_controller.dart';

/// Case-insensitive match over every active item's title and note body, sorted
/// by title. Shared by the phone search delegate and the wide inline search.
List<Item> searchItems(NotesController controller, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return controller.items
      .where(
        (i) =>
            i.content.toLowerCase().contains(q) ||
            (i.body?.toLowerCase().contains(q) ?? false),
      )
      .toList()
    ..sort(
      (a, b) => a.content.toLowerCase().compareTo(b.content.toLowerCase()),
    );
}

/// Full-text search over every active item. Returns the selected [Item] (via
/// `close`) so the caller can navigate to it; returns null if dismissed.
class ItemSearchDelegate extends SearchDelegate<Item?> {
  ItemSearchDelegate(this.controller, this._l)
    : super(searchFieldLabel: _l.searchHint);

  final NotesController controller;
  final AppLocalizations _l;

  // Smaller, lighter field text than the default title-sized search style.
  @override
  TextStyle? get searchFieldStyle =>
      const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w400);

  List<Item> _matches() => searchItems(controller, query);

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final results = _matches();

    if (query.trim().isEmpty) return const SizedBox.shrink();
    if (results.isEmpty) {
      return Center(
        child: Text(
          _l.searchEmpty,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        final isTask = item.type == ItemType.task;
        // Breadcrumb of ancestors (exclude the item itself) as the subtitle.
        final path = controller.pathTo(item.id);
        final trail = path.length > 1
            ? path.take(path.length - 1).map((e) => e.content).join(' › ')
            : null;

        return ListTile(
          leading: Icon(
            isTask
                ? (item.isDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded)
                : Icons.sticky_note_2_outlined,
            color: isTask ? cs.primary : cs.tertiary,
          ),
          title: Text(
            item.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: trail == null
              ? null
              : Text(trail, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => close(context, item),
        );
      },
    );
  }
}
