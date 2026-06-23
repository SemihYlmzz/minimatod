import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_info.dart';
import '../../../l10n/app_localizations.dart';

/// Which kind of feedback the form collects.
enum FeedbackKind { bug, advice }

/// Opens a small in-app form for [kind] feedback. On send it composes an email
/// to the support address — the message plus app version + platform — and hands
/// off to the mail app. No backend, no new dependency; swap the send for an HTTP
/// endpoint later if one-tap submit is wanted.
Future<void> showFeedbackSheet(
  BuildContext context, {
  required FeedbackKind kind,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // resize for the keyboard
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => _FeedbackSheet(kind: kind),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.kind});

  final FeedbackKind kind;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController _text = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {})); // toggles the Send button
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _text.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    final l = AppLocalizations.of(context);

    final info = await PackageInfo.fromPlatform();
    final platform = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    // Keep the subject category in English so reports stay easy to filter,
    // whatever language the sender used.
    final category = widget.kind == FeedbackKind.bug ? 'Bug report' : 'Idea';
    final subject = '[${AppInfo.appName}] $category — v${info.version}';
    final body =
        '$message\n\n———\nv${info.version} (${info.buildNumber}) · $platform';

    // Encode the query manually so spaces become %20 (some mail clients
    // mishandle the '+' that Uri's queryParameters would produce).
    final uri = Uri(
      scheme: 'mailto',
      path: AppInfo.supportEmail,
      query:
          'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.couldNotOpen(AppInfo.supportEmail))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final isBug = widget.kind == FeedbackKind.bug;
    final canSend = _text.text.trim().isNotEmpty && !_sending;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isBug ? l.reportBug : l.sendIdea,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l.feedbackEmailHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: isBug ? l.bugReportHint : l.adviceHint,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: canSend ? _send : null,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(l.send),
            ),
          ],
        ),
      ),
    );
  }
}
