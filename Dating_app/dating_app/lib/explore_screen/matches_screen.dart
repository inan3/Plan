import 'package:flutter/material.dart';

class MatchesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Desactiva la flecha de volver atrás
        title: Text('Tus matches'),
        backgroundColor: Colors.purple[800],
      ),
      body: Center(
        child: Text('Tus matches', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
