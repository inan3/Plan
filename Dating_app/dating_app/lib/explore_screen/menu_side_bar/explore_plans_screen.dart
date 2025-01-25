import 'package:flutter/material.dart';

class ExplorePlansScreen extends StatelessWidget {
  const ExplorePlansScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar Planes'),
      ),
      body: const Center(
        child: Text('Esta es la pantalla de Explorar Planes'),
      ),
    );
  }
}
