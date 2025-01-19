import 'package:flutter/material.dart';

class PlanSubmitButtons extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onCreate;

  const PlanSubmitButtons({
    Key? key,
    required this.onCancel,
    required this.onCreate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onCreate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
          ),
          child: const Text('Crear Plan'),
        ),
      ],
    );
  }
}
