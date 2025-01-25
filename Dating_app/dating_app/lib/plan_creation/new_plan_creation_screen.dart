import 'package:flutter/material.dart';
import '../main/colors.dart';
import 'plan_description_screen.dart';
import '../models/plan_model.dart'; // Importa el modelo de Plan

class NewPlanCreationScreen extends StatefulWidget {
  @override
  _NewPlanCreationScreenState createState() => _NewPlanCreationScreenState();
}

class _NewPlanCreationScreenState extends State<NewPlanCreationScreen> {
  String? _selectedPlan;

  final List<Map<String, dynamic>> _plans = [
    {'icon': Icons.sports_basketball, 'name': 'Deporte'},
    {'icon': Icons.local_dining, 'name': 'Cena'},
    {'icon': Icons.movie, 'name': 'Cine'},
    {'icon': Icons.nature_people, 'name': 'Excursión'},
    {'icon': Icons.music_note, 'name': 'Concierto'},
    {'icon': Icons.book, 'name': 'Lectura'},
    {'icon': Icons.beach_access, 'name': 'Playa'},
    {'icon': Icons.pool, 'name': 'Natación'},
    {'icon': Icons.brush, 'name': 'Pintura'},
    {'icon': Icons.coffee, 'name': 'Café'},
    {'icon': Icons.gamepad, 'name': 'Videojuegos'},
    {'icon': Icons.directions_bike, 'name': 'Ciclismo'},
    {'icon': Icons.camera, 'name': 'Fotografía'},
    {'icon': Icons.shopping_cart, 'name': 'Compras'},
    {'icon': Icons.pets, 'name': 'Paseo con mascotas'},
    {'icon': Icons.work, 'name': 'Trabajo'},
    {'icon': Icons.local_florist, 'name': 'Jardinería'},
    {'icon': Icons.flight_takeoff, 'name': 'Viaje'},
    {'icon': Icons.theater_comedy, 'name': 'Teatro'},
    {'icon': Icons.fitness_center, 'name': 'Gimnasio'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Botón flotante con "X" para salir
          Positioned(
            top: 45,
            left: 30,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context); // Vuelve a la pantalla anterior
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: AppColors.blue, size: 28),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 50),
                // Logo en la parte superior
                Image.asset(
                  'assets/plan-sin-fondo.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                // Texto explicativo
                const Text(
                  "Hazle saber a la gente el plan que deseas compartir.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Desplegable para seleccionar el tipo de plan
                DropdownButtonFormField<String>(
                  value: _selectedPlan,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  items: _plans.map((plan) {
                    return DropdownMenuItem<String>(
                      value: plan['name'],
                      child: Row(
                        children: [
                          Icon(plan['icon'], color: AppColors.blue),
                          const SizedBox(width: 10),
                          Text(plan['name'], style: const TextStyle(color: Colors.black)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedPlan = newValue;
                    });
                  },
                ),
                const Spacer(),
                // Botón de navegación hacia la siguiente pantalla
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: AppColors.blue, size: 32),
                      onPressed: _selectedPlan != null
                          ? () {
                              // Guarda el plan seleccionado en un modelo
                              final plan = PlanModel(
                              id: '', // Generado más adelante
                              type: _selectedPlan!,
                              description: '',
                              minAge: 0,
                              maxAge: 0,
                              location: '',
                              date: DateTime.now(),
                              createdBy: '', // Reemplaza con el ID del usuario actual
                            );


                              // Navega a la siguiente pantalla con el modelo
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlanDescriptionScreen(plan: plan),
                                ),
                              );
                            }
                          : null, // Deshabilitado si no se selecciona un plan
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
