import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../l10n/app_localizations.dart';

/// A full-screen, document-style read/write surface for an item's note — the
/// right-hand page of the detail [PageView] (Apple/Samsung Notes style).
///
/// The whole area is tappable to focus; the field grows and scrolls on its own.
/// Edits are debounced and flushed back through [onChanged] (which persists
/// them) — autosaving while typing, plus an immediate save when focus is lost.
/// (Stored as plain text/markdown for now; the rich editor can be layered on
/// later without changing this contract.)
class NotePage extends StatefulWidget {
  const NotePage({
    super.key,
    required this.text,
    required this.onChanged,
    this.focusNode,
  });

  final String text;
  final ValueChanged<String> onChanged;

  /// Owned by the parent so it can show a "Done" button while the note is
  /// focused and dismiss the keyboard.
  final FocusNode? focusNode;

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  Timer? _debounce;
  late String _lastSaved = widget.text;

  static const _debounceDelay = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    widget.focusNode?.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(NotePage old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode?.removeListener(_onFocusChange);
      widget.focusNode?.addListener(_onFocusChange);
    }
    // Adopt external changes (e.g. a future server sync) only while idle, so an
    // autosave reload can never yank the text out from under the cursor.
    final focused = widget.focusNode?.hasFocus ?? false;
    if (!focused && widget.text != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
      _lastSaved = widget.text;
    }
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _flush);
  }

  void _onFocusChange() {
    if (!(widget.focusNode?.hasFocus ?? false)) _flush();
  }

  /// Persists the current text if it changed since the last save.
  void _flush() {
    _debounce?.cancel();
    final text = _controller.text;
    if (text == _lastSaved) return;
    _lastSaved = text;
    widget.onChanged(text);
  }

  @override
  void dispose() {
    _flush();
    widget.focusNode?.removeListener(_onFocusChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            autofocus: false,
            expands: true,
            maxLines: null,
            minLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.55,
              color: cs.onSurface.withValues(alpha: 0.9),
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: l.noteBodyHint,
              hintStyle: TextStyle(
                fontSize: 15.5,
                height: 1.55,
                color: cs.onSurface.withValues(alpha: 0.32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
