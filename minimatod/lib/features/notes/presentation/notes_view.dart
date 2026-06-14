import 'package:flutter/material.dart';

class NotesView extends StatefulWidget {
  const NotesView({super.key});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Minimatod',
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
      body: Column(
        children: [
          Expanded(
            child: Center(
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
            ),
          ),
          _BottomInputBar(
            controller: _controller,
            isNote: _isNote,
            onTypeChanged: (v) => setState(() => _isNote = v),
            onAdd: () => _controller.clear(),
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
                  _AddButton(isNote: isNote, onPressed: onAdd),
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
  const _AddButton({required this.isNote, required this.onPressed});

  final bool isNote;
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
