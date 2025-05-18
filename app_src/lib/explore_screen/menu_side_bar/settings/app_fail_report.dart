// app_fail_report.dart
import 'package:flutter/material.dart';

class AppFailReportScreen extends StatelessWidget {
  const AppFailReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar fallos en la app'),
      ),
      body: const Center(
        child: Text('Pantalla de Reportar fallos en la app'),
      ),
    );
  }
}
