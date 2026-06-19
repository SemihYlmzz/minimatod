import 'package:flutter/material.dart';

import '../../../core/widgets/dismiss_keyboard.dart';
import '../../../l10n/app_localizations.dart';
import '../data/note_model.dart';

/// Result of [CreateItemPage]: the entered text and chosen item type.
typedef CreateItemResult = ({String content, ItemType type});

/// A full page for composing a new note or task. Returns a [CreateItemResult]
/// via `Navigator.pop`, or null if dismissed.
class CreateItemPage extends StatefulWidget {
  const CreateItemPage({super.key, this.startAsNote = true});

  final bool startAsNote;

  @override
  State<CreateItemPage> createState() => _CreateItemPageState();
}

class _CreateItemPageState extends State<CreateItemPage> {
  final TextEditingController _text = TextEditingController();
  late bool _isNote = widget.startAsNote;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onChanged);
  }

  @override
  void dispose() {
    _text.removeListener(_onChanged);
    _text.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _submit() {
    final content = _text.text.trim();
    if (content.isEmpty) return;
    Navigator.of(context).pop((
      content: content,
      type: _isNote ? ItemType.note : ItemType.task,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final canAdd = _text.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          _isNote ? l.addNote : l.addTask,
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
      body: DismissKeyboard(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The text field takes the space; the controls live at the
                // bottom, next to the keyboard and the user's thumbs.
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TextField(
                      controller: _text,
                      autofocus: true,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      textCapitalization: TextCapitalization.sentences,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: _isNote ? l.writeNoteHint : l.addTaskHint,
                        hintStyle:
                            TextStyle(color: cs.onSurface.withValues(alpha: 0.35)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _TypeChip(
                            label: l.note,
                            icon: Icons.sticky_note_2_outlined,
                            selected: _isNote,
                            onTap: () => setState(() => _isNote = true),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(
                            label: l.task,
                            icon: Icons.check_circle_outline_rounded,
                            selected: !_isNote,
                            onTap: () => setState(() => _isNote = false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: canAdd ? _submit : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: canAdd
                              ? cs.primary
                              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: canAdd
                              ? cs.onPrimary
                              : cs.onSurface.withValues(alpha: 0.35),
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color:
              selected ? cs.primary : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
