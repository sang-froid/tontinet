import 'package:flutter/material.dart';

void main() {
  runApp(const TontiNetApp());
}

/// Racine de l'application TontiNet (coquille vide, étape 0).
class TontiNetApp extends StatelessWidget {
  const TontiNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TontiNet',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('TontiNet')),
      ),
    );
  }
}
