import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Esto cerrará la pantalla actual y 
            // regresará a la pantalla anterior (ExploreScreen),
            // que es donde está el MainSideBarScreen.
            Navigator.pop(context);
          },
        ),
      ),
      body: const Center(
        child: Text('Esta es la pantalla de Perfil'),
      ),
    );
  }
}
