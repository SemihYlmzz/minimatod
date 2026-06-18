import 'package:flutter/material.dart';
import 'package:minimatod/core/brand/brand.dart';
import 'package:minimatod/features/notes/presentation/notes_controller.dart';
import 'package:minimatod/features/notes/presentation/notes_view.dart';

class MinimatodApp extends StatefulWidget {
  const MinimatodApp({super.key, required this.controller});

  final NotesController controller;

  @override
  State<MinimatodApp> createState() => _MinimatodAppState();
}

class _MinimatodAppState extends State<MinimatodApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Monochrome accent matching the brand mark (near-black + white).
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Brand.ink,
      brightness: Brightness.dark,
    ).copyWith(primary: Brand.paper, onPrimary: Brand.ink);

    final lightScheme = ColorScheme.fromSeed(
      seedColor: Brand.ink,
      brightness: Brightness.light,
    ).copyWith(primary: Brand.ink, onPrimary: Brand.paper);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      themeMode: ThemeMode.dark,
      home: NotesView(controller: widget.controller),
    );
  }
}
