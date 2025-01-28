import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart'; // Para Clipboard
import '../../main/colors.dart';
import '../../explore_screen/explore_screen.dart';
import '../../models/plan_model.dart';

class DateTimeScreen extends StatefulWidget {
  final PlanModel plan;

  const DateTimeScreen({Key? key, required this.plan}) : super(key: key);

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

  Future<String> _getCreatorName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No se encontró al usuario autenticado.");

      // Obtén el documento del usuario desde Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data()!['name'] ?? "Usuario desconocido";
      } else {
        throw Exception("No se encontró el nombre del usuario en Firestore.");
      }
    } catch (e) {
      print("Error al obtener el nombre del usuario: $e");
      return "Usuario desconocido";
    }
  }

  void _savePlanToFirestore() async {
    try {
      // Validación inicial
      if (_selectedDate == null || _selectedTime == null) {
        throw Exception("Fecha y hora no seleccionadas.");
      }

      // Obtén el UID del usuario actual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Usuario no autenticado");

      // Genera un ID único de 10 caracteres si aún no se ha generado
      if (widget.plan.id.isEmpty) {
        widget.plan.id = await PlanModel.generateUniqueId();
      }

      // Asigna el UID del usuario actual al campo createdBy
      widget.plan.createdBy = user.uid;

      // Obtén el nombre del creador
      widget.plan.creatorName = await _getCreatorName();

      // Asigna la fecha seleccionada al plan
      widget.plan.date = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Guarda la fecha de creación actual
      widget.plan.createdAt = DateTime.now();

      // Guarda el plan en Firestore
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.plan.id)
          .set(widget.plan.toMap());

      print('Plan guardado correctamente en Firestore.');
    } catch (e) {
      print('Error al guardar el plan en Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _finalizePlan() {
    if (_selectedDate != null && _selectedTime != null) {
      _savePlanToFirestore();
      _showSuccessPopup();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona la fecha y hora para continuar.'),
        ),
      );
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/plan-sin-fondo.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _finalizePlan,
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
