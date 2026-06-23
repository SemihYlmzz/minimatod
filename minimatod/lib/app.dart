import 'package:flutter/material.dart';
import 'package:minimatod/core/navigation/route_stack.dart';
import 'package:minimatod/core/settings/app_settings_controller.dart';
import 'package:minimatod/core/theme/app_themes.dart';
import 'package:minimatod/features/notes/presentation/app_shell.dart';
import 'package:minimatod/features/notes/presentation/notes_controller.dart';
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

class _MinimatodAppState extends State<MinimatodApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have changed notification permission in OS/browser settings
    // while away — re-check on resume so reminder badges self-correct.
    if (state == AppLifecycleState.resumed) {
      widget.controller.reminders?.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final reminders = widget.controller.reminders;
    final audio = widget.controller.audio;
    widget.controller.dispose();
    reminders?.dispose();
    audio?.dispose();
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
          navigatorObservers: [routeStackObserver],
          home: OnboardingGate(
            settings: widget.settings,
            forceShow: widget.showOnboarding,
            child: AppShell(
              controller: widget.controller,
              settings: widget.settings,
            ),
          ),
        );
      },
    );
  }
}
