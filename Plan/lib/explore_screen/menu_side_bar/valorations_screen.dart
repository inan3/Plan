import 'package:flutter/material.dart';

class ValorationsScreen extends StatelessWidget {
  const ValorationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valoraciones'),
      ),
      body: const Center(
        child: Text('Esta es la pantalla de Valoraciones'),
      ),
    );
  }
}
