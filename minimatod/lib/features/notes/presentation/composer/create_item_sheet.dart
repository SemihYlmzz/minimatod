import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/format/reminder_at.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../attachments/presentation/audio_controller.dart';
import '../../../attachments/presentation/audio_widgets.dart';
import '../../data/note_model.dart';
import '../widgets/item_visuals.dart';

/// Result of the create composer: the title, chosen item type, and the optional
/// icon / accent colour / reminder extras. [audio] is a freshly-recorded clip to
/// attach; [removeAudio] asks to delete the item's existing clip (edit only).
typedef CreateItemResult = ({
  String content,
  ItemType type,
  String? icon,
  int? color,
  DateTime? reminderAt,
  PendingRecording? audio,
  bool removeAudio,
});

/// Presents the composer as a modal bottom sheet (phone + iPad). Pass [initial]
/// to edit an existing item (prefills its values); omit it to create a new one.
/// Returns a [CreateItemResult] on submit, or null if dismissed.
Future<CreateItemResult?> showCreateItemSheet(
  BuildContext context, {
  bool startAsNote = true,
  Item? initial,
  NotificationService? notifications,
  AudioController? audio,
}) {
  return showModalBottomSheet<CreateItemResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CreateItemSheet(
      startAsNote: startAsNote,
      initial: initial,
      notifications: notifications,
      audio: audio,
    ),
  );
}

/// The inline panel shown at the bottom of the sheet (in place of the keyboard).
/// The keyboard itself is driven purely by the title field's focus — there's no
/// keyboard "mode".
enum _BottomMode { customize, reminder }

class _CreateItemSheet extends StatefulWidget {
  const _CreateItemSheet({
    required this.startAsNote,
    this.initial,
    this.notifications,
    this.audio,
  });

  final bool startAsNote;

  /// The item being edited, or null when creating a new one.
  final Item? initial;

  /// Used to prime/check notification permission when a reminder is set.
  final NotificationService? notifications;

  /// Records a voice note attached to the item on submit. Null hides the mic.
  final AudioController? audio;

  @override
  State<_CreateItemSheet> createState() => _CreateItemSheetState();
}

class _CreateItemSheetState extends State<_CreateItemSheet> {
  final TextEditingController _title = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  late bool _isNote;
  String? _iconKey;
  int? _color;
  DateTime? _reminder;

  /// Notification permission as last checked: granted / denied / default /
  /// unsupported, or null until first checked.
  String? _permStatus;

  /// The open inline panel, or null when none is open (collapsed bottom).
  _BottomMode? _mode;

  /// True while the reminder date/time dialogs are up, so the title regaining
  /// focus as a dialog pops doesn't auto-close the reminder panel (which made it
  /// feel like no reminder was set).
  bool _pickingReminder = false;

  /// Voice-note recording state for this composer session.
  bool _recording = false;
  PendingRecording? _pendingRecording;

  /// Edit only: the user deleted the item's existing clip (applied on submit).
  bool _removeExisting = false;

  /// Set once the sheet submits, so dispose knows a staged pending clip was kept
  /// (attached by the caller) rather than abandoned (its blob should be GC'd).
  bool _submitted = false;

  /// Whether a freshly-recorded clip is staged this session.
  bool get _hasNewClip => _pendingRecording != null;

  /// Whether the edited item still has its existing clip (no new take, not
  /// deleted). Always false when creating.
  bool get _hasExistingClip {
    final id = widget.initial?.id;
    if (id == null || _removeExisting || _hasNewClip) return false;
    return widget.audio?.audioOf(id) != null;
  }

  /// Whether the composer currently holds a clip (new or existing).
  bool get _hasClip => _hasNewClip || _hasExistingClip;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _title.text = initial.content;
      _isNote = initial.type == ItemType.note;
      _iconKey = initial.icon;
      _color = initial.color;
      _reminder = initial.reminderAt;
    } else {
      _isNote = widget.startAsNote;
    }
    _title.addListener(_onChanged);
    // Opening the keyboard (focusing the title) closes any open option panel.
    _titleFocus.addListener(() {
      if (_titleFocus.hasFocus && _mode != null && !_pickingReminder) {
        setState(() => _mode = null);
      }
    });
  }

  @override
  void dispose() {
    // A clip recorded but never submitted (sheet dismissed) leaves an orphaned
    // blob — discard it. Once submitted, the caller owns attaching it.
    final pending = _pendingRecording;
    if (pending != null && !_submitted) widget.audio?.discardPending(pending);
    _title.removeListener(_onChanged);
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// The accent the row will use: the chosen colour, else the type accent
  /// (notes → tertiary, tasks → primary) — kept identical to `ItemRow` so the
  /// preview matches the real tile.
  Color get _accent {
    if (_color != null) return Color(_color!);
    final cs = Theme.of(context).colorScheme;
    return _isNote ? cs.tertiary : cs.primary;
  }

  /// Toggles an inline panel: tapping the open one collapses the bottom. Opening
  /// one drops the keyboard so the panel takes its place.
  void _toggleMode(_BottomMode mode) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() => _mode = _mode == mode ? null : mode);
  }

  /// Tapping empty space drops the keyboard and collapses any open panel, so the
  /// bottom returns to its resting (empty) state.
  void _collapseBottom() {
    FocusScope.of(context).unfocus();
    if (_mode != null) setState(() => _mode = null);
  }

  void _submit() {
    final content = _title.text.trim();
    if (content.isEmpty) return;
    HapticFeedback.mediumImpact();
    _submitted = true;
    Navigator.of(context).pop((
      content: content,
      type: _isNote ? ItemType.note : ItemType.task,
      icon: _isNote ? _iconKey : null,
      color: _color,
      reminderAt: _reminder,
      audio: _pendingRecording,
      // A staged delete only matters when no new take replaces the clip.
      removeAudio: _removeExisting && !_hasNewClip,
    ));
  }

  /// Records a voice note (or stops + keeps it). It attaches to the item on
  /// submit. A new take replaces any earlier one from this session.
  Future<void> _toggleRecord() async {
    final audio = widget.audio;
    if (audio == null) return;
    HapticFeedback.selectionClick();
    if (_recording) {
      final old = _pendingRecording;
      final rec = await audio.stopRecording();
      // A re-take supersedes the previous staged clip — GC its orphaned blob.
      if (rec != null && old != null && old.hash != rec.hash) {
        await audio.discardPending(old);
      }
      if (mounted) {
        setState(() {
          _recording = false;
          if (rec != null) _pendingRecording = rec;
        });
      }
    } else {
      final ok = await audio.startRecording();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).micPermissionNeeded),
            ),
          );
        }
        return;
      }
      if (mounted) setState(() => _recording = true);
    }
  }

  /// Plays the staged clip — the new take if present, else the item's existing
  /// one (edit). Toggles off if it's already playing.
  void _playClip() {
    final audio = widget.audio;
    if (audio == null) return;
    final pending = _pendingRecording;
    if (pending != null) {
      audio.playPending(pending);
    } else {
      final id = widget.initial?.id;
      if (id != null) audio.playFor(id);
    }
  }

  /// Whether the staged clip is the one currently playing.
  bool get _clipPlaying {
    final audio = widget.audio;
    if (audio == null) return false;
    final pending = _pendingRecording;
    if (pending != null) return audio.isPlayingPending(pending);
    final id = widget.initial?.id;
    return id != null && audio.isPlaying(id);
  }

  /// Removes the staged clip: discards a new take's blob, or (edit) stages the
  /// existing clip for deletion on submit.
  Future<void> _deleteClip() async {
    HapticFeedback.selectionClick();
    final pending = _pendingRecording;
    if (pending != null) {
      await widget.audio?.discardPending(pending);
      if (mounted) setState(() => _pendingRecording = null);
    } else if (mounted) {
      setState(() => _removeExisting = true);
    }
  }

  void _setReminderPreset(DateTime when) {
    HapticFeedback.selectionClick();
    setState(() => _reminder = when);
    _onReminderSet();
  }

  /// After a reminder is chosen, make sure we have notification permission:
  /// show a priming dialog the first time, then reflect the result so the panel
  /// can warn if reminders are blocked.
  Future<void> _onReminderSet() async {
    final n = widget.notifications;
    if (n == null) return;
    var status = await n.currentStatus();
    if (status == 'default' && mounted) {
      final wantsIt = await _showPrimingDialog();
      if (wantsIt == true) {
        await n.requestPermission();
        status = await n.currentStatus();
      }
    }
    if (mounted) setState(() => _permStatus = status);
  }

  Future<void> _showEnableHelp() {
    final l = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.enableReminders),
        content: Text(
          kIsWeb ? l.enableInstructionsWeb : l.enableInstructionsNative,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.done),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPrimingDialog() {
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.enableReminders),
        content: Text(l.enableRemindersBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.enable),
          ),
        ],
      ),
    );
  }

  /// ~3 hours from now, rounded to the hour (still today-ish).
  DateTime _laterToday() {
    final t = DateTime.now().add(const Duration(hours: 3));
    return DateTime(t.year, t.month, t.day, t.hour);
  }

  DateTime _tomorrowMorning() {
    final d = DateTime.now().add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day, 9);
  }

  DateTime _nextWeek() {
    final d = DateTime.now().add(const Duration(days: 7));
    return DateTime(d.year, d.month, d.day, 9);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    // Keep the reminder panel open and the keyboard down across the date/time
    // dialogs: each dialog pop momentarily refocuses the title, which would
    // otherwise close the panel and pop the keyboard — making it feel like
    // nothing was set.
    _pickingReminder = true;
    try {
      final date = await showDatePicker(
        context: context,
        initialDate: _reminder ?? now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 10),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_reminder ?? now),
      );
      if (!mounted) return;
      final t = time ?? const TimeOfDay(hour: 9, minute: 0);
      setState(() {
        _reminder = DateTime(date.year, date.month, date.day, t.hour, t.minute);
        _mode = _BottomMode.reminder;
      });
      await _onReminderSet();
    } finally {
      if (mounted) FocusScope.of(context).unfocus();
      _pickingReminder = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final canAdd = _title.text.trim().isNotEmpty;
    // The keyboard and the expanded panel never coexist: while the keyboard is
    // up (or still animating), the panel stays collapsed. The options bar above
    // it stays visible regardless.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isTask = !_isNote;
    final previewIcon = _isNote
        ? (itemIconData(_iconKey) ?? Icons.sticky_note_2_outlined)
        : Icons.radio_button_unchecked_rounded;
    // Same tile fill as ItemRow, so the preview reads as the real row.
    final tileColor = Color.alphaBlend(
      cs.surfaceContainerHighest.withValues(alpha: isTask ? 0.5 : 0.3),
      cs.surface,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          // Tapping the sheet's empty areas collapses the keyboard/panel.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _collapseBottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grab handle.
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Cancel — top-right, as in the mockup.
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(
                      l.cancel,
                      style: TextStyle(
                        fontSize: 15.5,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Live preview: the exact list row this item will become, with
                // the title editable inline.
                GestureDetector(
                  onTap: _titleFocus.requestFocus,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.10),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            previewIcon,
                            size: isTask ? 22 : 19,
                            color: _accent.withValues(alpha: isTask ? 0.7 : 1),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _title,
                            focusNode: _titleFocus,
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            style: TextStyle(
                              fontSize: 15.5,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface.withValues(alpha: 0.92),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: _isNote ? l.addNote : l.addTask,
                              hintStyle: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                        if (_reminder != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.event_outlined, size: 11, color: _accent),
                          const SizedBox(width: 3),
                          Text(
                            formatReminderAt(
                              _reminder!,
                              Localizations.localeOf(context),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
                const SizedBox(height: 12),

                // Options bar (always visible): note/task toggle, colour/icon,
                // reminder — plus the submit button. The expanded panel for the
                // selected option sits below.
                Row(
                  children: [
                    // First option: toggle between note and task. The icon shows
                    // the current type (note glyph / checkmark).
                    _ModeButton(
                      icon: _isNote
                          ? Icons.sticky_note_2_outlined
                          : Icons.check_circle_rounded,
                      active: true,
                      accent: _accent,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isNote = !_isNote);
                      },
                    ),
                    const SizedBox(width: 8),
                    _ModeButton(
                      icon: Icons.palette_outlined,
                      active: _mode == _BottomMode.customize,
                      accent: _accent,
                      onTap: () => _toggleMode(_BottomMode.customize),
                    ),
                    const SizedBox(width: 8),
                    _ModeButton(
                      icon: Icons.event_outlined,
                      active: _mode == _BottomMode.reminder,
                      accent: _accent,
                      onTap: () => _toggleMode(_BottomMode.reminder),
                    ),
                    if (widget.audio != null) ...[
                      const SizedBox(width: 8),
                      _ModeButton(
                        icon: _recording
                            ? Icons.stop_rounded
                            : (_hasClip
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded),
                        active: _recording || _hasClip,
                        accent: _recording ? cs.error : _accent,
                        onTap: _toggleRecord,
                      ),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: canAdd ? _submit : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: canAdd
                              ? _accent
                              : cs.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 24,
                          color: canAdd
                              ? _onAccent(_accent)
                              : cs.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),

                // The staged voice note (new take, or the item's existing clip):
                // play / delete it right here. Rebuilds on audio notifications so
                // the play/stop icon tracks playback.
                if (widget.audio != null && _hasClip)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ListenableBuilder(
                      listenable: widget.audio!,
                      builder: (context, _) => _ClipChip(
                        playing: _clipPlaying,
                        accent: _accent,
                        onPlay: _playClip,
                        onDelete: _deleteClip,
                      ),
                    ),
                  ),

                // The expanded option panel. Dynamic height (fits its content),
                // but premium-smooth: AnimatedSize eases the height to the
                // *current* panel while AnimatedSwitcher cross-fades — the
                // custom layoutBuilder sizes to the incoming panel so colour ↔
                // reminder never holds the taller height.
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        for (final child in previousChildren)
                          Positioned(left: 0, right: 0, top: 0, child: child),
                        ?currentChild,
                      ],
                    ),
                    child: (keyboardOpen || _mode == null)
                        ? const SizedBox(
                            key: ValueKey('none'),
                            width: double.infinity,
                          )
                        : SizedBox(
                            key: ValueKey(_mode),
                            width: double.infinity,
                            child: _buildPanel(context, l),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, AppLocalizations l) {
    switch (_mode) {
      case null:
        return const SizedBox.shrink();
      case _BottomMode.customize:
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tasks keep the checkbox affordance, so only notes pick an icon.
              if (_isNote) ...[
                _SectionLabel(l.iconLabel),
                const SizedBox(height: 10),
                _IconGrid(
                  selectedKey: _iconKey,
                  accent: _accent,
                  onSelect: (key) {
                    HapticFeedback.selectionClick();
                    setState(() => _iconKey = _iconKey == key ? null : key);
                  },
                ),
                const SizedBox(height: 18),
              ],
              _SectionLabel(l.colorLabel),
              const SizedBox(height: 10),
              _ColorRow(
                selected: _color,
                onSelect: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _color = _color == value ? null : value);
                },
              ),
            ],
          ),
        );
      case _BottomMode.reminder:
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(l.reminderLabel),
              const SizedBox(height: 10),
              // Quick presets cover the common cases in one tap.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ReminderPreset(
                    label: l.reminderLaterToday,
                    onTap: () => _setReminderPreset(_laterToday()),
                  ),
                  _ReminderPreset(
                    label: l.reminderTomorrow,
                    onTap: () => _setReminderPreset(_tomorrowMorning()),
                  ),
                  _ReminderPreset(
                    label: l.reminderNextWeek,
                    onTap: () => _setReminderPreset(_nextWeek()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: FilledButton.tonalIcon(
                      onPressed: _pickReminder,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _reminder == null
                            ? l.setReminder
                            : formatReminderAt(
                                _reminder!,
                                Localizations.localeOf(context),
                              ),
                      ),
                    ),
                  ),
                  if (_reminder != null)
                    IconButton(
                      tooltip: l.cancel,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _reminder = null);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              // Warn when a reminder is set but notifications won't fire. When
              // the prompt can still appear ('default') offer "Enable"; once
              // hard-blocked on web there's no API to re-prompt or open
              // settings, so offer "How to enable" instructions instead.
              if (_reminder != null &&
                  _permStatus != null &&
                  _permStatus != 'granted')
                _RemindersBlockedNote(
                  message: l.remindersBlocked,
                  actionLabel: _permStatus == 'default'
                      ? l.enable
                      : l.howToEnable,
                  onAction: _permStatus == 'default'
                      ? _onReminderSet
                      : _showEnableHelp,
                ),
            ],
          ),
        );
    }
  }

  /// Readable foreground for an accent fill (the palette colours are light).
  Color _onAccent(Color accent) {
    return ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

/// A tappable quick-reminder preset chip.
class _ReminderPreset extends StatelessWidget {
  const _ReminderPreset({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

/// Inline warning shown when a reminder is set but notifications aren't allowed.
class _RemindersBlockedNote extends StatelessWidget {
  const _RemindersBlockedNote({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;

  /// Optional action: "Enable" (prompt) or "How to enable" (instructions).
  /// Both null when nothing actionable is available.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAction = actionLabel != null && onAction != null;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: EdgeInsets.fromLTRB(12, 10, hasAction ? 4 : 12, 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (hasAction)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// The staged voice-note chip in the composer: a filled play/stop button, a
/// label, and a delete. Same look as the detail [VoiceNoteBar]'s clip row.
class _ClipChip extends StatelessWidget {
  const _ClipChip({
    required this.playing,
    required this.accent,
    required this.onPlay,
    required this.onDelete,
  });

  final bool playing;
  final Color accent;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPlay,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 22,
                color: readableOnAccent(accent),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              l.voiceNote,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          IconButton(
            tooltip: l.deleteVoiceNote,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// One of the option buttons (colour/icon or reminder) in the options bar.
class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 42,
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.16)
              : cs.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? accent : cs.outline.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? accent : cs.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: cs.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.selectedKey,
    required this.accent,
    required this.onSelect,
  });

  final String? selectedKey;
  final Color accent;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in kItemIcons)
          GestureDetector(
            onTap: () => onSelect(option.key),
            child: _IconTile(
              icon: option.icon,
              selected: option.key == selectedKey,
              accent: accent,
              cs: cs,
            ),
          ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.selected,
    required this.accent,
    required this.cs,
  });

  final IconData icon;
  final bool selected;
  final Color accent;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.16)
            : cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? accent : cs.outline.withValues(alpha: 0.25),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Icon(
        icon,
        size: 22,
        color: selected ? accent : cs.onSurface.withValues(alpha: 0.7),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.selected, required this.onSelect});

  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in kItemColors)
          GestureDetector(
            onTap: () => onSelect(color.toARGB32()),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.toARGB32() == selected
                      ? cs.onSurface
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
