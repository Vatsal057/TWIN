import 'package:flutter/material.dart';

/// Width classes the UI adapts to.
///
/// The game was designed phone-first. On a desktop browser a single stretched
/// column looks broken — buttons a metre wide, text lines too long to read — so
/// content gets a maximum width and the chat moves out of the bottom sheet and
/// into a permanent side panel.
enum WidthClass {
  /// Phones, and narrow browser windows.
  compact,

  /// Tablets, split-screen browsers.
  medium,

  /// Desktop browsers with room for the game and chat side by side.
  expanded,
}

class Layout {
  Layout._();

  /// Below this, chat stays a bottom sheet.
  static const sidePanelBreakpoint = 900.0;
  static const mediumBreakpoint = 620.0;

  /// Reading width for the main column. Wider than this and lines get hard to
  /// scan; the game is almost entirely text.
  static const contentMaxWidth = 560.0;

  /// Docked chat width on wide screens.
  static const chatPanelWidth = 360.0;

  static WidthClass of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= sidePanelBreakpoint) return WidthClass.expanded;
    if (width >= mediumBreakpoint) return WidthClass.medium;
    return WidthClass.compact;
  }

  /// True when there is room to dock chat beside the game instead of under it.
  static bool hasRoomForSideChat(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= sidePanelBreakpoint;

  static bool isCompact(BuildContext context) =>
      Layout.of(context) == WidthClass.compact;
}

/// Centres its child and caps its width, so every screen reads the same whether
/// it is on a phone or a 27-inch monitor.
class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.child,
    this.maxWidth = Layout.contentMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
