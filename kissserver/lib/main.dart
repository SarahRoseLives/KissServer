// File: main.dart

import 'package:flutter/material.dart';
import 'ui/home.dart'; // Import the new home screen UI

void main() {
  runApp(const KissBridgeApp());
}

/// The root widget of the KISS-TCP Bridge application.
class KissBridgeApp extends StatelessWidget {
  const KissBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KISS-TCP Bridge',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        primaryColor: Colors.blueGrey[900],
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          labelStyle: const TextStyle(color: Colors.blueAccent),
        ),
        useMaterial3: true,
      ),
      home: const KissBridgeHomePage(), // This points to your modified UI
    );
  }
}