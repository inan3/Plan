import 'package:flutter/material.dart';
import '../../main/colors.dart';
import '../../explore_screen/explore_screen.dart';

class DateTimeScreen extends StatefulWidget {
  const DateTimeScreen({Key? key}) : super(key: key);

  @override
  State<DateTimeScreen> createState() => _DateTimeScreenState();
}

class _DateTimeScreenState extends State<DateTimeScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  void _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        Future.delayed(const Duration(seconds: 4), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: AppColors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: AppColors.blue,
                size: 50,
              ),
              const SizedBox(height: 10),
              Text(
                "¡Plan creado con éxito!",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                  fontFamily: 'Roboto',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Puedes ver los detalles de tu plan\nen Mis Planes",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.blue,
                  fontFamily: 'Roboto',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    ).then((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ExploreScreen()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Contenido principal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo en el centro
                Center(
                  child: Image.asset(
                    'assets/plan-sin-fondo.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),

                // Texto principal
                const Text(
                  "Selecciona la fecha y hora del encuentro",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Selección de fecha
                Center(
                  child: ElevatedButton(
                    onPressed: _selectDate,
                    child: const Text("Seleccionar Fecha"),
                  ),
                ),
                if (_selectedDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Center(
                      child: Text(
                        "Fecha seleccionada: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Selección de hora
                Center(
                  child: ElevatedButton(
                    onPressed: _selectTime,
                    child: const Text("Seleccionar Hora"),
                  ),
                ),
                if (_selectedTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Center(
                      child: Text(
                        "Hora seleccionada: ${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Botón "X" para salir
          Positioned(
            top: 45,
            left: 16,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ExploreScreen()),
                  (route) => false,
                );
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: AppColors.blue,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),

      // Barra inferior con flechas
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSuccessPopup,
        backgroundColor: AppColors.blue,
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text(
          "Finalizar Plan",
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
