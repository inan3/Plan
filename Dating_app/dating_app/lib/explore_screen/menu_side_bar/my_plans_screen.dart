import 'package:flutter/material.dart';

class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Planes'),
      ),
      body: const Center(
        child: Text('Esta es la pantalla de Mis Planes'),
      ),
    );
  }
}
