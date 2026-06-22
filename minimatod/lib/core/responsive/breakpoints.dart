import 'package:flutter/widgets.dart';

/// Width at/above which the UI is treated as "wide" (tablets, iPad in either
/// orientation, large web/desktop windows). Width-based, not device-based, so it
/// also reacts to window resizing on web/desktop.
const double kWideBreakpoint = 720;

/// Comfortable reading width for centered content on wide screens, so lists and
/// the note editor don't stretch edge-to-edge.
const double kContentMaxWidth = 720;

/// True when the current layout width is wide enough for tablet-style layouts.
bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;
