import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() => runApp(const NexoApp());

class NexoApp extends StatelessWidget {
  const NexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const violet = Color(0xFF8B5CF6);
    return MaterialApp(
      title: 'Nexo Finanças',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080C16),
        colorScheme: const ColorScheme.dark(primary: violet, secondary: Color(0xFF41D69B), surface: Color(0xFF111827)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B1220),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF243047))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF243047))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: violet, width: 1.5)),
        ),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ),
      home: const LoginScreen(),
    );
  }
}

