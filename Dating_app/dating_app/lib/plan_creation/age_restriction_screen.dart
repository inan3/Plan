import 'package:flutter/material.dart';
import '../main/colors.dart';
import '../explore_screen/explore_screen.dart';
import 'max_participants_num.dart';

class AgeRestrictionScreen extends StatefulWidget {
  const AgeRestrictionScreen({Key? key}) : super(key: key);

  @override
  _AgeRestrictionScreenState createState() => _AgeRestrictionScreenState();
}

class _AgeRestrictionScreenState extends State<AgeRestrictionScreen> {
  RangeValues _selectedAgeRange = const RangeValues(18, 45);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Esconde el teclado
      child: Scaffold(
        body: Stack(
          children: [
            // Botón flotante con "X" para salir
            Positioned(
              top: 30,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const ExploreScreen()),
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 100),
                  const Center(
                    child: Text(
                      "Restricción de Edad",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Edad",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        "${_selectedAgeRange.start.round()} - ${_selectedAgeRange.end.round()}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      activeTrackColor: AppColors.blue,
                      inactiveTrackColor: AppColors.blue.withOpacity(0.3),
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                        elevation: 4,
                        pressedElevation: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 20,
                      ),
                    ),
                    child: RangeSlider(
                      values: _selectedAgeRange,
                      min: 18,
                      max: 100,
                      divisions: 82,
                      labels: RangeLabels(
                        _selectedAgeRange.start.round().toString(),
                        _selectedAgeRange.end.round().toString(),
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          _selectedAgeRange = values;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                onPressed: () {
                  // Al pulsar la flecha, vamos a la pantalla de máximo de participantes
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MaxParticipantsNumScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
