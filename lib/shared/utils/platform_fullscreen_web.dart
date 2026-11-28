import 'dart:js_interop';

@JS('toggleBrowserFullscreen')
external bool _toggleBrowserFullscreen();

bool toggleBrowserFullscreen() {
  try {
    return _toggleBrowserFullscreen();
  } catch (e) {
    return false;
  }
}
