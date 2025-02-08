import 'package:flutter/material.dart';
import 'package:dating_app/main/colors.dart';
import 'package:dating_app/plan_creation/new_plan_creation_screen.dart';
import 'package:dating_app/plan_joining/plan_join_request.dart';
import 'plan_action_button.dart'; // Asegúrate de importar tu widget PlanActionButton

class AddPlanScreen extends StatelessWidget {
  const AddPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          '¡Crea o Únete a un Plan!',
          style: TextStyle(
            fontFamily: 'Inter', // Asegúrate de tener la fuente Inter incluida en pubspec.yaml
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // Utilizamos un Stack para colocar los botones flotantes sobre el contenido principal.
      body: Stack(
        children: [
          // Contenido principal de la pantalla
          const Center(
            child: Text(
              'Add Plan Screen',
              style: TextStyle(fontSize: 18),
            ),
          ),
          // Botón flotante "Unirse a Plan"
          Positioned(
            bottom: 160,
            left: 20,
            child: PlanActionButton(
              heroTag: 'joinPlan',
              label: 'Unirse a Plan',
              iconPath: 'assets/union.png', // Se usa Image.asset para PNG
              onPressed: () => JoinPlanRequestScreen.showJoinPlanDialog(context),
              margin: const EdgeInsets.only(left: 0, bottom: 0),
              borderColor: const Color.fromARGB(236, 0, 4, 227),
              borderWidth: 1,
              textColor: AppColors.blue,
              iconColor: AppColors.blue,
            ),
          ),
          // Botón flotante "Crear Plan"
          Positioned(
            bottom: 160,
            right: 20,
            child: PlanActionButton(
              heroTag: 'createPlan',
              label: 'Crear Plan',
              iconPath: 'assets/anadir.svg', // Se usa flutter_svg para SVG
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NewPlanCreationScreen(),
                  ),
                );
              },
              margin: const EdgeInsets.only(right: 0, bottom: 0),
              backgroundColor: AppColors.blue,
              borderWidth: 0,
              textColor: Colors.white,
              iconColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
