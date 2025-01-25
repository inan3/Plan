import 'package:flutter/material.dart';
import 'height_selection_screen.dart'; // Importa la pantalla de selección de altura

const Color backgroundColor = Colors.purple; // Fondo morado

class AgeScreen extends StatefulWidget {
  final String username;
  final String gender;
  final String interest;

  AgeScreen({
    required this.username,
    required this.gender,
    required this.interest,
  });

  @override
  _AgeScreenState createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  double _age = 25.0; // Edad inicial (en años)

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
                '¿Cuántos años tienes?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              Text(
                '${_age.toStringAsFixed(0)} años',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Slider(
                value: _age,
                min: 18.0,
                max: 100.0,
                divisions: 82,
                label: '${_age.toStringAsFixed(0)} años',
                activeColor: Colors.pink,
                inactiveColor: Colors.purple[200],
                onChanged: (double value) {
                  setState(() {
                    _age = value;
                  });
                },
              ),
              SizedBox(height: 30),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HeightSelectionScreen(
                        username: widget.username,
                        gender: widget.gender,
                        interest: widget.interest,
                        age: _age.toStringAsFixed(0), // Pasa la edad
                      ),
                    ),
                  );
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
