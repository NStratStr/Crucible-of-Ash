import 'package:flutter/material.dart';
import 'shared/widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AshenCrucibleApp());
}

class AshenCrucibleApp extends StatelessWidget {
  final bool enableAutoBattle;
  const AshenCrucibleApp({super.key, this.enableAutoBattle = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Ashen Crucible',
      debugShowCheckedModeBanner: false,
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
