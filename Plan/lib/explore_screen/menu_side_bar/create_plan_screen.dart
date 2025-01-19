import 'package:flutter/material.dart';

class CreatePlanScreen extends StatelessWidget {
  const CreatePlanScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Plan'),
      ),
      body: const Center(
        child: Text('Esta es la pantalla de Crear Plan'),
      ),
    );
  }
}
