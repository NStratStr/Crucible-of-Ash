import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// Conditional import for web
import 'platform_fullscreen_stub.dart'
    if (dart.library.js_interop) 'platform_fullscreen_web.dart' as platform_impl;

class PlatformFullscreen {
  static void toggleFullscreen() {
    if (kIsWeb) {
      platform_impl.toggleBrowserFullscreen();
    } else {
      // Mobile native fallback (Android/iOS SystemChrome)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }
}
