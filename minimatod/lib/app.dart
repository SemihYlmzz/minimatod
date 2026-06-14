import 'package:flutter/material.dart';
import 'package:minimatod/features/notes/presentation/notes_view.dart';

class MinimatodApp extends StatefulWidget {
  const MinimatodApp({super.key});

  @override
  State<MinimatodApp> createState() => _MinimatodAppState();
}

class _MinimatodAppState extends State<MinimatodApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
        home: NotesView(),
    );
  }
}