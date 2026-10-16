import 'dart:js_interop';

@JS('toggleBrowserFullscreen')
external void _toggleBrowserFullscreen();

void toggleBrowserFullscreen() {
  try {
    _toggleBrowserFullscreen();
  } catch (e) {
    // Graceful fallback
  }
}
