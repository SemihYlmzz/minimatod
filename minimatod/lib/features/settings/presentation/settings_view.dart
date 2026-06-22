import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_info.dart';
import '../../../core/brand/logo_painter.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/theme/app_themes.dart';
import '../../../l10n/app_localizations.dart';

/// Settings / about screen. Hosts appearance (theme + language) preferences plus
/// the legally-required Privacy Policy link, support contact, web app and
/// version info.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.settings});

  final AppSettingsController settings;

  Future<void> _open(BuildContext context, Uri uri) async {
    final l = AppLocalizations.of(context);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.couldNotOpen(uri.toString()))));
    }
  }

  String _themeLabel(AppLocalizations l, ThemeChoice c) => switch (c) {
    ThemeChoice.auto => l.themeAuto,
    ThemeChoice.light => l.themeLight,
    ThemeChoice.dark => l.themeDark,
    ThemeChoice.darkBlue => l.themeDarkBlue,
  };

  String _languageLabel(AppLocalizations l, LanguageChoice c) => switch (c) {
    LanguageChoice.system => l.languageSystem,
    LanguageChoice.en => l.languageEnglish,
    LanguageChoice.tr => l.languageTurkish,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          l.settings,
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
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Brand header.
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: MinimatodLogo(
                              size: 56,
                              markFraction: 0.86,
                              markColor: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppInfo.appName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const _VersionText(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  _SectionLabel(l.appearance),
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    label: l.theme,
                    subtitle: _themeLabel(l, settings.theme),
                    onTap: () => _pickTheme(context, l),
                  ),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    label: l.language,
                    subtitle: _languageLabel(l, settings.language),
                    onTap: () => _pickLanguage(context, l),
                  ),

                  const SizedBox(height: 8),
                  _SectionLabel(l.about),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    label: l.privacyPolicy,
                    onTap: () => _open(context, Uri.parse(AppInfo.privacyUrl)),
                  ),
                  _SettingsTile(
                    icon: Icons.mail_outline_rounded,
                    label: l.contactSupport,
                    subtitle: AppInfo.supportEmail,
                    onTap: () => _open(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: AppInfo.supportEmail,
                        query: 'subject=Minimatod Support',
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.public_rounded,
                    label: l.website,
                    onTap: () => _open(context, Uri.parse(AppInfo.website)),
                  ),
                  _SettingsTile(
                    icon: Icons.open_in_new_rounded,
                    label: l.openWebApp,
                    onTap: () => _open(context, Uri.parse(AppInfo.webApp)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, AppLocalizations l) async {
    final choice = await showModalBottomSheet<ThemeChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        top: false,
        child: RadioGroup<ThemeChoice>(
          groupValue: settings.theme,
          onChanged: (v) => Navigator.of(context).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in ThemeChoice.values)
                RadioListTile<ThemeChoice>(
                  value: c,
                  title: Text(_themeLabel(l, c)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (choice != null) await settings.setTheme(choice);
  }

  Future<void> _pickLanguage(BuildContext context, AppLocalizations l) async {
    final choice = await showModalBottomSheet<LanguageChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        top: false,
        child: RadioGroup<LanguageChoice>(
          groupValue: settings.language,
          onChanged: (v) => Navigator.of(context).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in LanguageChoice.values)
                RadioListTile<LanguageChoice>(
                  value: c,
                  title: Text(_languageLabel(l, c)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (choice != null) await settings.setLanguage(choice);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the app version read from the native bundle (single source of truth =
/// pubspec). Loads once; renders nothing until available.
class _VersionText extends StatefulWidget {
  const _VersionText();

  @override
  State<_VersionText> createState() => _VersionTextState();
}

class _VersionTextState extends State<_VersionText> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    final version = _version;
    if (version == null) return const SizedBox(height: 16);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Text(
      AppLocalizations.of(context).versionLabel(version),
      style: theme.textTheme.bodySmall?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}
