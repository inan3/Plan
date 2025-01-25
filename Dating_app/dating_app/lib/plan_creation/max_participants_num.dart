import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main/colors.dart';
import '../../explore_screen/explore_screen.dart';
// Asegúrate de importar tu pantalla de MeetingLocationScreen
import 'meeting_location_screen.dart';

class MaxParticipantsNumScreen extends StatefulWidget {
  const MaxParticipantsNumScreen({Key? key}) : super(key: key);

  @override
  State<MaxParticipantsNumScreen> createState() =>
      _MaxParticipantsNumScreenState();
}

class _MaxParticipantsNumScreenState extends State<MaxParticipantsNumScreen> {
  final TextEditingController _participantsController = TextEditingController();
  bool _noMaxParticipants = false;

  @override
  void initState() {
    super.initState();
    _participantsController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _participantsController.dispose();
    super.dispose();
  }

  /// Oculta el teclado si se hace tap fuera del campo de texto
  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// Evitamos que se reajuste toda la pantalla cuando aparece el teclado
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: _hideKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            /// Usamos LayoutBuilder + SingleChildScrollView + ConstrainedBox
            /// para garantizar que haya área de toque suficiente debajo de la caja.
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
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
                          const Text(
                            "Número máximo de participantes",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // Botón para alternar "Sin límite"
                          Row(
                            children: [
                              Checkbox(
                                value: _noMaxParticipants,
                                onChanged: (val) {
                                  setState(() {
                                    _noMaxParticipants = val ?? false;
                                    if (_noMaxParticipants) {
                                      // Limpiamos el campo y ocultamos el teclado
                                      _participantsController.clear();
                                      _hideKeyboard();
                                    }
                                  });
                                },
                              ),
                              const Text(
                                "Sin límite de participantes",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),

                          // Caja de texto para el número máximo (solo si NO está en "Sin límite")
                          if (!_noMaxParticipants) ...[
                            Container(
                              height: 60,
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
                                controller: _participantsController,
                                keyboardType: TextInputType.number,
                                // Solo permite dígitos
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  hintText: "Número de participantes (mínimo 1)",
                                  border: InputBorder.none,
                                  counterText: "",
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
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
                  // Regresa a ExploreScreen eliminando toda la pila de navegación
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const ExploreScreen()),
                    (Route<dynamic> route) => false,
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

      // Barra de navegación inferior con flechas
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flecha para regresar a la pantalla anterior
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            // Flecha para avanzar
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: AppColors.blue, size: 32),
              onPressed: () {
                // Validamos: si NO está marcado "Sin límite" y la caja está vacía o < 1
                if (!_noMaxParticipants) {
                  final text = _participantsController.text;
                  if (text.isEmpty ||
                      int.tryParse(text) == null ||
                      int.parse(text) < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Debes poner al menos 1 participante o marcar 'Sin límite'.",
                        ),
                      ),
                    );
                    return;
                  }
                }

                // Si pasa la validación, navegamos a MeetingLocationScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MeetingLocationScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
