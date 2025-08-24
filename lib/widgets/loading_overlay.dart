import 'package:flutter/material.dart';

/// A simple loading overlay that can be shown and dismissed easily
class LoadingOverlay {
  OverlayEntry? _overlay;

  /// Shows a loading overlay with the given message
  static LoadingOverlay show({
    required BuildContext context,
    String message = 'Loading...',
  }) {
    final overlay = LoadingOverlay();
    overlay._show(context, message);
    return overlay;
  }

  /// Shows the loading overlay
  void _show(BuildContext context, String message) {
    final overlay = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    _overlay = overlay;
  }

  /// Hides the loading overlay
  void hide() {
    _overlay?.remove();
    _overlay = null;
  }
}
