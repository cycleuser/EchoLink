import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/providers/providers.dart';

void main() {
  runApp(const ProviderScope(child: EchoLinkApp()));
}

class EchoLinkApp extends ConsumerStatefulWidget {
  const EchoLinkApp({super.key});

  @override
  ConsumerState<EchoLinkApp> createState() => _EchoLinkAppState();
}

class _EchoLinkAppState extends ConsumerState<EchoLinkApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transferProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
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
