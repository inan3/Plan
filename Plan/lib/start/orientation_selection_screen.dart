import 'package:flutter/material.dart';
import 'interest_selection_screen.dart'; // Importa la pantalla de selección de interés

const Color backgroundColor = Colors.purple; // Fondo morado

class OrientationSelectionScreen extends StatefulWidget {
  final String username;
  final String gender;

  OrientationSelectionScreen({required this.username, required this.gender});

  @override
  _OrientationSelectionScreenState createState() =>
      _OrientationSelectionScreenState();
}

class _OrientationSelectionScreenState
    extends State<OrientationSelectionScreen> {
  String? selectedOrientation;

  // Widget para construir cada opción de orientación sexual
  Widget _buildOrientationOption(String orientation) {
    bool isSelected = selectedOrientation == orientation;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedOrientation = orientation;
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10, horizontal: 30),
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.pink, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.black26,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            orientation,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'LoveMe',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple[800],
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '¿Qué orientación sexual tienes?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              // Opciones de orientación sexual
              _buildOrientationOption('Heterosexual'),
              _buildOrientationOption('Homosexual'),
              _buildOrientationOption('Bisexual'),
              _buildOrientationOption('Otro'),
              SizedBox(height: 30),
              // Botón de continuar
              GestureDetector(
                onTap: () {
                  if (selectedOrientation != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InterestSelectionScreen(
                          username: widget.username,
                          gender: widget.gender,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Por favor, selecciona una orientación sexual.'),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 200,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.pink, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Enlace para regresar
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Regresa a la pantalla anterior
                },
                child: Text(
                  '¿Regresar?',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
