import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/settings/app_settings_controller.dart';
import 'notes_controller.dart';
import 'notes_view.dart';
import 'wide/wide_home_shell.dart';

/// Chooses the layout for the current width:
/// * narrow (phones) → the push-navigation [NotesView] (unchanged).
/// * wide (tablets/iPad, large windows) → the three-pane [WideHomeShell].
///
/// Width-based so it also reacts live to web/desktop window resizing.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.controller, required this.settings});

  final NotesController controller;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    if (isWide(context)) {
      return WideHomeShell(controller: controller, settings: settings);
    }
    return NotesView(controller: controller, settings: settings);
  }
}
