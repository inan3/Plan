import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Ayuda'),
      ),
      body: const Center(
        child: Text('Esta es la pantalla de Centro de Ayuda'),
      ),
    );
  }
}
