import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'shared/widgets/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (e) {
    debugPrint('[Orientation] Warning setting landscape lock: $e');
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase] Warning during initialization: $e');
  }
  runApp(const AshenCrucibleApp());
}

class AshenScrollBehavior extends MaterialScrollBehavior {
  const AshenScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

class AshenCrucibleApp extends StatelessWidget {
  final bool enableAutoBattle;
  const AshenCrucibleApp({super.key, this.enableAutoBattle = true});

  static EdgeInsets _rotateInsetsClockwise(EdgeInsets insets) {
    return EdgeInsets.only(
      left: insets.bottom,
      top: insets.left,
      right: insets.top,
      bottom: insets.right,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crucible of Ash',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AshenScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D14),
        primaryColor: const Color(0xFFB3261E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB3261E),
          secondary: Color(0xFFE5A93C),
          surface: Color(0xFF181820),
        ),
        fontFamily: 'Roboto',
      ),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final mq = MediaQuery.of(context);
        // Always load and lock the game in Landscape: if a phone/tablet is currently held
        // upright in Portrait (width < height), rotate the viewport 90° into Landscape
        // with matching swapped dimensions and SafeArea insets so players immediately turn
        // their phone sideways and never land in a broken portrait layout.
        if (mq.size.width > 0 && mq.size.width < mq.size.height) {
          final landscapeMq = mq.copyWith(
            size: Size(mq.size.height, mq.size.width),
            padding: _rotateInsetsClockwise(mq.padding),
            viewPadding: _rotateInsetsClockwise(mq.viewPadding),
            viewInsets: _rotateInsetsClockwise(mq.viewInsets),
          );
          return ColoredBox(
            color: const Color(0xFF0D0D14),
            child: RotatedBox(
              quarterTurns: 1,
              child: MediaQuery(
                data: landscapeMq,
                child: SizedBox(
                  width: landscapeMq.size.width,
                  height: landscapeMq.size.height,
                  child: child,
                ),
              ),
            ),
          );
        }
        return child;
      },
      home: AppShell(enableAutoBattle: enableAutoBattle),
    );
  }
}
