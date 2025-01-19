import 'package:flutter/material.dart';

class MessagesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Desactiva la flecha de volver atrás
        title: Text('Tus mensajes'),
        backgroundColor: Colors.purple[800],
      ),
      body: Center(
        child: Text('Tus mensajes', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
