import 'package:flutter/material.dart';
import '../main/colors.dart';
import '../explore_screen/explore_screen.dart';
import 'age_restriction_screen.dart';

class PlanDescriptionScreen extends StatefulWidget {
  final String planType;

  const PlanDescriptionScreen({required this.planType, Key? key})
      : super(key: key);

  @override
  State<PlanDescriptionScreen> createState() => _PlanDescriptionScreenState();
}

class _PlanDescriptionScreenState extends State<PlanDescriptionScreen> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Evita que el contenido se reajuste automáticamente cuando aparece el teclado
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        // Cuando hacemos tap en cualquier sitio que no sea el TextField, se oculta teclado
        onTap: _hideKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Usamos LayoutBuilder -> SingleChildScrollView -> ConstrainedBox
            // para asegurarnos de que el área "vacía" sea clicable.
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // Para permitir scroll si el contenido lo requiere
                  child: ConstrainedBox(
                    // Mínimo igual al alto total disponible
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 50),
                          Center(
                            child: Image.asset(
                              'assets/plan-sin-fondo.png',
                              height: 150,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Describe tu plan de ${widget.planType}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 120,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.blue),
                            ),
                            child: TextField(
                              controller: _descriptionController,
                              maxLength: 500,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                hintText: "¡No te cortes!",
                                border: InputBorder.none,
                                counterText: "",
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "${_descriptionController.text.length}/500",
                              style:
                                  const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // --- Aquí puede haber más widgets, espacio, etc. ---
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Botón flotante con "X" para salir (encima de todo)
            Positioned(
              top: 45,
              left: 30,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const ExploreScreen()),
                    (Route<dynamic> route) => false, // Elimina rutas previas
                  );
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
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.blue, size: 32),
              onPressed: () {
                Navigator.pop(context); // Regresa a la pantalla anterior
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: AppColors.blue, size: 32),
              onPressed: _descriptionController.text.isNotEmpty
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AgeRestrictionScreen(),
                        ),
                      );
                    }
                  : null, // Deshabilitado si está vacío
            ),
          ],
        ),
      ),
    );
  }
}
