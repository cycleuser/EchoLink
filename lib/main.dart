import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/providers/providers.dart';

void main() {
  runApp(const ProviderScope(child: EchoLinkApp()));
}

class EchoLinkApp extends ConsumerWidget {
  const EchoLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      title: 'EchoLink',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}