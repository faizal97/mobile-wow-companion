import 'package:flutter/material.dart';
import '../../models/character.dart';

class TdGameScreen extends StatelessWidget {
  final List<WowCharacter> characters;
  final int keystoneLevel;
  const TdGameScreen({super.key, required this.characters, required this.keystoneLevel});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('TD Game - Coming Soon')));
}
