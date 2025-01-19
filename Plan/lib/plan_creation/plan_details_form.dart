import 'package:flutter/material.dart';

class PlanDetailsForm extends StatelessWidget {
  final TextEditingController themeController;
  final TextEditingController descriptionController;
  final List<String> genderOptions;
  final ValueChanged<String?> onGenderSelected;
  final ValueChanged<int?> onMinAgeChanged;
  final ValueChanged<int?> onMaxAgeChanged;

  const PlanDetailsForm({
    Key? key,
    required this.themeController,
    required this.descriptionController,
    required this.genderOptions,
    required this.onGenderSelected,
    required this.onMinAgeChanged,
    required this.onMaxAgeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tema del Plan:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        TextField(
          controller: themeController,
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
            hintText: 'Introduce el tema del plan',
          ),
        ),
        // Otros campos para descripción, edad, etc.
      ],
    );
  }
}
