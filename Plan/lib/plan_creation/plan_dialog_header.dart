import 'package:flutter/material.dart';

class PlanDialogHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'Crear un nuevo plan',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}
