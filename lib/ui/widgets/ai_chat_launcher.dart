import 'package:flutter/material.dart';

import 'package:accounting_app/ui/widgets/ai_chat_sheet.dart';

/// Navigator for the whole app.
///
/// The launcher sits above the Navigator in the tree (it is installed by
/// [MaterialApp.builder] so it can float over every screen), so it cannot
/// reach a Navigator through its own context and uses this key instead.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// The floating assistant button, drawn on top of every screen.
///
/// Draggable, because a fixed button would eventually cover something that
/// matters on one of the app's denser report screens.
class AiChatLauncher extends StatefulWidget {
  const AiChatLauncher({super.key});

  @override
  State<AiChatLauncher> createState() => _AiChatLauncherState();
}

class _AiChatLauncherState extends State<AiChatLauncher> {
  static const double _size = 52;
  static const double _margin = 16;

  /// Null until dragged, meaning "resting in the default corner".
  Offset? _position;

  /// Hidden while the panel is open, so it does not float over the sheet.
  bool _open = false;

  Future<void> _openChat() async {
    final navigatorContext = appNavigatorKey.currentContext;
    if (navigatorContext == null) return;
    setState(() => _open = true);
    try {
      await AiChatSheet.show(navigatorContext);
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_open) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final screen = media.size;

    // Keep the button clear of system insets at rest and after a drag.
    const minX = _margin;
    final maxX = screen.width - _size - _margin;
    final minY = media.padding.top + _margin;
    final maxY = screen.height - _size - _margin - media.padding.bottom;

    final resting = Offset(maxX, maxY - 60);
    final current = _position ?? resting;
    final clamped = Offset(
      current.dx.clamp(minX, maxX < minX ? minX : maxX),
      current.dy.clamp(minY, maxY < minY ? minY : maxY),
    );

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      child: GestureDetector(
        onPanUpdate: (details) => setState(() {
          _position = (_position ?? resting) + details.delta;
        }),
        child: Material(
          color: const Color(0xFF2C5545),
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _openChat,
            child: const SizedBox(
              width: _size,
              height: _size,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
