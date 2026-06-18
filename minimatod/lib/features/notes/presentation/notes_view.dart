import 'package:flutter/material.dart';

import '../../settings/presentation/settings_view.dart';
import '../data/note_model.dart';
import 'notes_controller.dart';

/// A single level of the note/task tree.
///
/// Recursive: the root screen has `parent == null` and lists root items;
/// tapping a row pushes another [NotesView] scoped to that item, showing its
/// children. New items added here are nested under [parent].
class NotesView extends StatefulWidget {
  const NotesView({super.key, required this.controller, this.parent});

  final NotesController controller;
  final Item? parent;

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  final TextEditingController _controller = TextEditingController();

  bool _isNote = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    await widget.controller.addItem(
      content: text,
      type: _isNote ? ItemType.note : ItemType.task,
      parentId: widget.parent?.id,
    );
    _controller.clear();
  }

  void _openItem(Item item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotesView(controller: widget.controller, parent: item),
      ),
    );
  }

  Future<void> _deleteCurrent() async {
    final parent = widget.parent;
    if (parent == null) return;
    await widget.controller.deleteItem(parent.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// Builds the list, grouping notes and tasks. The type selected in the bottom
  /// bar comes first; the other group follows, split by a horizontal divider.
  Widget _buildList(List<Item> items) {
    final notes = items.where((i) => i.type == ItemType.note).toList();
    final tasks = items.where((i) => i.type == ItemType.task).toList();

    final first = _isNote ? notes : tasks;
    final second = _isNote ? tasks : notes;

    final children = <Widget>[
      for (final item in first) _row(item),
      if (first.isNotEmpty && second.isNotEmpty)
        _SectionDivider(label: _isNote ? 'Tasks' : 'Notes'),
      for (final item in second) _row(item),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: children,
    );
  }

  Widget _row(Item item) {
    final counts = widget.controller.descendantTaskCounts(item.id);
    return _ItemRow(
      item: item,
      completedTasks: counts.completed,
      uncompletedTasks: counts.uncompleted,
      onTap: () => _openItem(item),
      onToggleDone: () => widget.controller.toggleDone(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isRoot = widget.parent == null;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          isRoot ? 'Minimatod' : widget.parent!.content,
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
        actions: [
          if (isRoot)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsView()),
              ),
            )
          else
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) {
                if (value == 0) _deleteCurrent();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final items = widget.controller.childrenOf(widget.parent?.id);
                if (items.isEmpty) return const _EmptyState();
                return _buildList(items);
              },
            ),
          ),
          _BottomInputBar(
            controller: _controller,
            isNote: _isNote,
            onTypeChanged: (v) => setState(() => _isNote = v),
            onAdd: _add,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.note_alt_outlined,
              size: 34,
              color: cs.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Nothing here yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.35),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a note or task below',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// A flat, tappable row for one item. Tapping opens the item's own screen.
///
/// Notes and tasks use slightly different tile colors. The trailing badges show
/// how many descendant **tasks** are completed / uncompleted (notes excluded).
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.completedTasks,
    required this.uncompletedTasks,
    required this.onTap,
    required this.onToggleDone,
  });

  final Item item;
  final int completedTasks;
  final int uncompletedTasks;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTask = item.type == ItemType.task;
    final isDone = isTask && item.isDone;
    final hasTaskCounts = completedTasks > 0 || uncompletedTasks > 0;

    // Subtle difference between tasks and notes.
    final accent = isTask ? cs.primary : cs.tertiary;
    final tileColor = cs.surfaceContainerHighest.withOpacity(isTask ? 0.5 : 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outline.withOpacity(0.10)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                // Leading icon chip — checkbox for tasks, note glyph otherwise.
                GestureDetector(
                  onTap: isTask ? onToggleDone : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(isDone ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isTask
                          ? (isDone
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded)
                          : Icons.sticky_note_2_outlined,
                      size: isTask ? 22 : 19,
                      color: accent.withOpacity(isTask && !isDone ? 0.7 : 1),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Content.
                Expanded(
                  child: Text(
                    item.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: isDone
                          ? cs.onSurface.withOpacity(0.4)
                          : cs.onSurface.withOpacity(0.92),
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                // Descendant task counts (tasks only).
                if (hasTaskCounts) ...[
                  const SizedBox(width: 10),
                  _CountBadge(
                    icon: Icons.check_rounded,
                    count: completedTasks,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  _CountBadge(
                    icon: Icons.circle_outlined,
                    count: uncompletedTasks,
                    color: cs.onSurface.withOpacity(0.55),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurface.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labeled separator between the notes group and the tasks group.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lineColor = cs.outline.withOpacity(0.18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, thickness: 1, color: lineColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: cs.onSurface.withOpacity(0.45),
              ),
            ),
          ),
          Expanded(child: Divider(height: 1, thickness: 1, color: lineColor)),
        ],
      ),
    );
  }
}

/// A small icon + number pill used to show descendant task counts.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomInputBar extends StatelessWidget {
  const _BottomInputBar({
    required this.controller,
    required this.isNote,
    required this.onTypeChanged,
    required this.onAdd,
  });

  final TextEditingController controller;
  final bool isNote;
  final ValueChanged<bool> onTypeChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeChip(
                    label: 'Note',
                    icon: Icons.sticky_note_2_outlined,
                    selected: isNote,
                    onTap: () => onTypeChanged(true),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: 'Task',
                    icon: Icons.check_circle_outline_rounded,
                    selected: !isNote,
                    onTap: () => onTypeChanged(false),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 5,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => onAdd(),
                        decoration: InputDecoration(
                          hintText: isNote ? 'Write a note…' : 'Add a task…',
                          hintStyle: TextStyle(
                            color: cs.onSurface.withOpacity(0.35),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _AddButton(onPressed: onAdd),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary
              : cs.surfaceContainerHighest.withOpacity(0.55),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? cs.onPrimary : cs.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? cs.onPrimary : cs.onSurface.withOpacity(0.5),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.add_rounded, color: cs.onPrimary, size: 26),
      ),
    );
  }
}
