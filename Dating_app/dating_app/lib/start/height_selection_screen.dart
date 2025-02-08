import 'package:flutter/material.dart';
import 'photo_selection_screen.dart';

class HeightSelectionScreen extends StatefulWidget {
  final String username;
  final String gender;
  final String interest;
  final String age; // Agregado para manejar la edad.

  const HeightSelectionScreen({super.key, 
    required this.username,
    required this.gender,
    required this.interest,
    required this.age,
  });

  @override
  _HeightSelectionScreenState createState() => _HeightSelectionScreenState();
}

class _HeightSelectionScreenState extends State<HeightSelectionScreen> {
  double _height = 160.0; // Altura inicial (en cm)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Selecciona tu altura'),
        backgroundColor: Colors.purple,
      ),
      backgroundColor: Colors.purple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¿Cuánto mides?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 30),
            Text(
              '${_height.toStringAsFixed(0)} cm',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Slider(
              value: _height,
              min: 120.0,
              max: 220.0,
              divisions: 100,
              label: '${_height.toStringAsFixed(0)} cm',
              activeColor: Colors.pink,
              inactiveColor: Colors.purple[200],
              onChanged: (value) {
                setState(() {
                  _height = value;
                });
              },
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhotoSelectionScreen(
                      username: widget.username,
                      gender: widget.gender,
                      interest: widget.interest,
                      height: _height.toStringAsFixed(0),
                      age: widget.age, // Pasa la edad al siguiente screen
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink, // Sustituido primary por backgroundColor
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Continuar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
