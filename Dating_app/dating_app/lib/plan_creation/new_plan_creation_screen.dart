import 'package:flutter/material.dart';
import '../main/colors.dart';
import 'plan_description_screen.dart';
import '../models/plan_model.dart';

class NewPlanCreationScreen extends StatefulWidget {
  const NewPlanCreationScreen({super.key});

  @override
  _NewPlanCreationScreenState createState() => _NewPlanCreationScreenState();
}

class _NewPlanCreationScreenState extends State<NewPlanCreationScreen> {
  String? _selectedPlan;
  String? _customPlan;
  IconData? _selectedIcon;
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  final List<Map<String, dynamic>> _plans = [
    {'icon': Icons.lightbulb, 'name': 'Otro (Especificar)'},
    {'icon': Icons.sports_basketball, 'name': 'Baloncesto'},
    {'icon': Icons.book, 'name': 'Biblioteca'},
    {'icon': Icons.local_dining, 'name': 'Cena'},
    {'icon': Icons.shopping_cart, 'name': 'Compras'},
    {'icon': Icons.movie, 'name': 'Cine'},
    {'icon': Icons.coffee, 'name': 'Café'},
    {'icon': Icons.directions_bike, 'name': 'Ciclismo'},
    {'icon': Icons.music_note, 'name': 'Concierto'},
    {'icon': Icons.nature_people, 'name': 'Excursión'},
    {'icon': Icons.beach_access, 'name': 'Playa'},
    {'icon': Icons.pool, 'name': 'Natación'},
    {'icon': Icons.brush, 'name': 'Pintura'},
    {'icon': Icons.camera, 'name': 'Fotografía'},
    {'icon': Icons.fitness_center, 'name': 'Gimnasio'},
    {'icon': Icons.local_florist, 'name': 'Jardinería'},
    {'icon': Icons.flight_takeoff, 'name': 'Viaje'},
    {'icon': Icons.theater_comedy, 'name': 'Teatro'},
    {'icon': Icons.sports_soccer, 'name': 'Fútbol'},
    {'icon': Icons.directions_run, 'name': 'Correr'},
    {'icon': Icons.work, 'name': 'Trabajo'},
    {'icon': Icons.school, 'name': 'Estudiar'},
    {'icon': Icons.pets, 'name': 'Paseo con mascotas'},
    {'icon': Icons.gamepad, 'name': 'Videojuegos'},
    {'icon': Icons.sports_mma, 'name': 'Boxeo'},
    {'icon': Icons.sports_volleyball, 'name': 'Voleibol'},
    {'icon': Icons.directions_walk, 'name': 'Senderismo'},
    {'icon': Icons.nightlife, 'name': 'Discoteca'},
    {'icon': Icons.volunteer_activism, 'name': 'Voluntariado'},
    {'icon': Icons.kitchen, 'name': 'Cocinar'},
    {'icon': Icons.golf_course, 'name': 'Golf'},
    {'icon': Icons.bike_scooter, 'name': 'Patinaje'},
    {'icon': Icons.home, 'name': 'Reunión en casa'},
    {'icon': Icons.public, 'name': 'Visitar monumentos'},
    {'icon': Icons.art_track, 'name': 'Museos'},
    {'icon': Icons.wb_sunny, 'name': 'Camping'},
    {'icon': Icons.gesture, 'name': 'Yoga'},
    {'icon': Icons.restaurant_menu, 'name': 'Degustación de comida'},
    {'icon': Icons.attractions, 'name': 'Parque de atracciones'},
    {'icon': Icons.rowing, 'name': 'Remo'},
    {'icon': Icons.accessibility_new, 'name': 'Zumba'},
    {'icon': Icons.handyman, 'name': 'Talleres'},
    {'icon': Icons.shopping_bag, 'name': 'Mercados'},
    {'icon': Icons.water, 'name': 'Pesca'},
    {'icon': Icons.auto_awesome, 'name': 'Fotografía nocturna'},
    {'icon': Icons.sports_tennis, 'name': 'Tenis'},
    {'icon': Icons.local_bar, 'name': 'Bar'},
    {'icon': Icons.fireplace, 'name': 'Fogata'},
    {'icon': Icons.car_repair, 'name': 'Rally'},
    {'icon': Icons.snowboarding, 'name': 'Esquí'},
  ];

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isDropdownOpen = true;
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isDropdownOpen = false;
    });
  }

OverlayEntry _createOverlayEntry() {
  return OverlayEntry(
    builder: (context) => GestureDetector( // Agrega este GestureDetector
      behavior: HitTestBehavior.opaque, // Captura toques fuera del menú
      onTap: _closeDropdown, // Cierra el dropdown al tocar fuera
      child: Stack(
        children: [
          Positioned(
            left: 20, 
            top: 300, 
            width: 340, 
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: ListView.builder(
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Icon(
                        _plans[index]['icon'],
                        color: AppColors.blue,
                      ),
                      title: Text(
                        _plans[index]['name'],
                        style: TextStyle(color: Colors.black, fontFamily: 'Roboto'),
                      ),
                      onTap: () {
                        if (_plans[index]['name'] == 'Otro (Especificar)') {
                          _closeDropdown();
                          _showCustomPlanDialog();
                        } else {
                          setState(() {
                            _selectedPlan = _plans[index]['name'];
                            _selectedIcon = _plans[index]['icon'];
                            _customPlan = null;
                          });
                          _closeDropdown();
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  void _showCustomPlanDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String customPlan = _customPlan ?? '';
        return AlertDialog(
          title: const Text("Especificar Plan"),
          content: TextField(
            maxLength: 30,
            controller: TextEditingController(text: customPlan),
            onChanged: (value) {
              customPlan = value;
            },
            decoration: const InputDecoration(hintText: "Describe tu plan (máx. 30 caracteres)"),
          ),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Aceptar"),
              onPressed: () {
                setState(() {
                  _customPlan = customPlan.isNotEmpty ? customPlan : null;
                  _selectedPlan = null; // Asegura que solo un tipo de plan esté activo
                  _selectedIcon = Icons.lightbulb;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

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
                  height: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                // Texto explicativo
                const Text(
                  "Hazle saber a la gente el plan que deseas compartir.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue,
                    fontFamily: 'Roboto',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Desplegable para seleccionar el tipo de plan
                GestureDetector(
                  onTap: _toggleDropdown,
                  child: Container(
                    width: 300, // Especifica el ancho deseado aquí
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (_selectedIcon != null)
                              Icon(_selectedIcon, color: AppColors.blue),
                            if (_selectedIcon != null)
                              const SizedBox(width: 10),
                            Text(
                              _customPlan ?? _selectedPlan ?? "Elige un plan",
                              style: const TextStyle(color: Colors.black, fontFamily: 'Roboto'),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.blue),
                      ],
                    ),
                  ),
                ),

                const Spacer(),
                // Botón de navegación hacia la siguiente pantalla
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 32),
                      onPressed: () {
                        if (_selectedPlan != null || _customPlan != null) {
                          final plan = PlanModel(
                            id: '', // Generado más adelante
                            type: _customPlan ?? _selectedPlan!,
                            description: '',
                            minAge: 0,
                            maxAge: 0,
                            location: '',
                            date: DateTime.now(),
                            createdBy: '', // Reemplaza con el ID del usuario actual
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlanDescriptionScreen(plan: plan),
                            ),
                          );
                        }
                      },
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
