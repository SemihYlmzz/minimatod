import 'package:flutter/material.dart';
import 'package:minimatod/core/settings/app_settings_controller.dart';
import 'package:minimatod/core/theme/app_themes.dart';
import 'package:minimatod/features/notes/presentation/notes_controller.dart';
import 'package:minimatod/features/notes/presentation/notes_view.dart';
import 'package:minimatod/features/onboarding/presentation/onboarding_gate.dart';
import 'package:minimatod/l10n/app_localizations.dart';

class MinimatodApp extends StatefulWidget {
  const MinimatodApp({
    super.key,
    required this.controller,
    required this.settings,
    this.showOnboarding = false,
  });

  final NotesController controller;
  final AppSettingsController settings;

  /// Force the onboarding to replay on every launch (dev flag from main).
  final bool showOnboarding;

  @override
  State<MinimatodApp> createState() => _MinimatodAppState();
}

class _MinimatodAppState extends State<MinimatodApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    widget.settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final resolved = AppThemes.resolve(widget.settings.theme);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          theme: resolved.theme,
          darkTheme: resolved.darkTheme,
          themeMode: resolved.themeMode,
          locale: widget.settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingGate(
            settings: widget.settings,
            forceShow: widget.showOnboarding,
            child: NotesView(
              controller: widget.controller,
              settings: widget.settings,
            ),
          ),
        );
      },
    );
  }
}
