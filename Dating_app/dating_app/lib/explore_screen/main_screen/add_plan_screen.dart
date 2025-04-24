import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dating_app/main/colors.dart';
import 'package:dating_app/plan_creation/new_plan_creation_screen.dart';
import 'package:dating_app/plan_joining/plan_join_request.dart';
import 'plan_action_button.dart'; // Asegúrate de importar tu widget PlanActionButton

class AddPlanScreen extends StatelessWidget {
  const AddPlanScreen({super.key});

  // Widget auxiliar para aplicar efecto frosted glass sin sombra
  Widget _buildFrostedButton({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Se elimina el AppBar para que todo esté sobre el mismo fondo
      body: Stack(
        children: [
          // Fondo degradado de azul oscuro a rojo oscuro.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFC7A9E9),
                  const Color.fromARGB(255, 195, 94, 94),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Contenido principal y botones
          SafeArea(
            child: Stack(
              children: [
                // Botón "Unirse a Plan" en la esquina superior izquierda con efecto frosted glass
                Positioned(
                  top: 20,
                  left: 20,
                  child: _buildFrostedButton(
                    child: PlanActionButton(
                      heroTag: 'joinPlan',
                      label: 'Unirse a Plan',
                      iconPath: 'assets/union.png',
                      onPressed: () =>
                          JoinPlanRequestScreen.showJoinPlanDialog(context),
                      margin: const EdgeInsets.all(0),
                      backgroundColor: Colors.transparent,
                      borderColor: const Color.fromARGB(236, 0, 4, 227),
                      borderWidth: 1,
                      textColor: AppColors.blue,
                      iconColor: AppColors.blue,
                    ),
                  ),
                ),
                // Botón "Crear Plan" en la esquina superior derecha con efecto frosted glass
                Positioned(
                  top: 20,
                  right: 20,
                  child: _buildFrostedButton(
                    child: PlanActionButton(
                      heroTag: 'createPlan',
                      label: 'Crear Plan',
                      // Se actualiza el ícono para usar assets/anadir.svg
                      iconPath: 'assets/anadir.svg',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NewPlanCreationScreen(),
                          ),
                        );
                      },
                      margin: const EdgeInsets.all(0),
                      backgroundColor: Colors.transparent,
                      borderWidth: 0,
                      textColor: Colors.white,
                      iconColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
