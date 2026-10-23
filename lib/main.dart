import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'shared/widgets/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Ashen Crucible',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AshenScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111114),
        primaryColor: const Color(0xFFB3261E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB3261E),
          secondary: Color(0xFFE5A93C),
          surface: Color(0xFF181820),
        ),
        fontFamily: 'Roboto',
      ),
      home: AppShell(enableAutoBattle: enableAutoBattle),
    );
  }
}
