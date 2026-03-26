import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: EchoLinkApp()));
}

class EchoLinkApp extends StatelessWidget {
  const EchoLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoLink',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}