import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'screens/app_shell.dart';
import 'services/session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  runApp(const MemoraApp());
}

class MemoraApp extends StatelessWidget {
  const MemoraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEMORA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
