import 'package:flutter/material.dart';

class CloseSessionScreen extends StatelessWidget {
  const CloseSessionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Normalmente, la lógica de cierre de sesión se manejaría
    // en otro lugar o al momento de seleccionar la opción.
    // Esta pantalla es meramente ilustrativa.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerrar Sesión'),
      ),
      body: const Center(
        child: Text('Esta es la pantalla de Cerrar Sesión'),
      ),
    );
  }
}
