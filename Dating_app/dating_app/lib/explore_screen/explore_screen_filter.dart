import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main/colors.dart'; // Asegúrate de tener definido AppColors

class ExploreScreenFilterDialog extends StatefulWidget {
  const ExploreScreenFilterDialog({Key? key}) : super(key: key);

  @override
  _ExploreScreenFilterDialogState createState() =>
      _ExploreScreenFilterDialogState();
}

class _ExploreScreenFilterDialogState extends State<ExploreScreenFilterDialog> {
  // Variables de filtro
  String planBusqueda = ''; // Para búsqueda por nombre o descripción
  String? planPredeterminado; // Para seleccionar de una lista predeterminada
  // Lista de planes predeterminados de ejemplo
  final List<String> tiposPlan = ['Deportivo', 'Cultural', 'Social', 'Otro'];

  // Variables de región
  String regionBusqueda = '';
  // Aquí podrías agregar variables para radio, ciudad o país

  // Rango de edad (valor mínimo y máximo)
  RangeValues edadRange = const RangeValues(18, 60);

  // Género seleccionado: 0 - Hombres, 1 - Mujeres, 2 - Todo el mundo
  int generoSeleccionado = 2;

  // Para simular obtener la ubicación actual (en una implementación real usarías el paquete de geolocalización)
  void _obtenerUbicacion() {
    // Lógica para obtener la ubicación (GPS)
    // Por ahora solo simulamos con un valor
    setState(() {
      regionBusqueda = 'Ubicación actual';
    });
  }

  void _aplicarFiltros() {
    // Aquí debes aplicar la lógica para filtrar los planes con los valores obtenidos
    // Por ejemplo, puedes pasar estos valores al widget principal o realizar una consulta a Firestore.
    Navigator.of(context).pop({
      'planBusqueda': planBusqueda,
      'planPredeterminado': planPredeterminado,
      'regionBusqueda': regionBusqueda,
      'edadMin': edadRange.start,
      'edadMax': edadRange.end,
      'genero': generoSeleccionado,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        // Evita que el pop up ocupe toda la pantalla
        padding: const EdgeInsets.all(10.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título
                    const Text(
                      'Filtrar Planes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ¿Qué tipo de planes buscas?
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¿Qué tipo de planes buscas?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Selección predeterminada o búsqueda por nombre:
                    // Dropdown para planes predeterminados
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        labelText: 'Tipo de plan',
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                      dropdownColor: AppColors.blue, // O el color que prefieras
                      style: const TextStyle(color: Colors.white),
                      value: planPredeterminado,
                      items: tiposPlan.map((String plan) {
                        return DropdownMenuItem<String>(
                          value: plan,
                          child: Text(plan),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          planPredeterminado = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    // Campo de búsqueda por nombre o descripción:
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.3),
                        hintText: 'Buscar por nombre o descripción',
                        hintStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onChanged: (value) {
                        planBusqueda = value;
                      },
                    ),
                    const SizedBox(height: 20),
                    // ¿En qué región buscas planes?
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¿En qué región buscas planes?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Campo para región
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.3),
                        hintText: 'Ciudad, país o radio (km)',
                        hintStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.my_location, color: Colors.white),
                          onPressed: _obtenerUbicacion,
                        ),
                      ),
                      onChanged: (value) {
                        regionBusqueda = value;
                      },
                    ),
                    const SizedBox(height: 20),
                    // ¿Qué rango de edad?
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¿Qué rango de edad?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Deslizable para rango de edad
                    RangeSlider(
                      values: edadRange,
                      min: 18,
                      max: 100,
                      divisions: 82,
                      activeColor: AppColors.blue,
                      inactiveColor: Colors.white.withOpacity(0.3),
                      labels: RangeLabels(
                        edadRange.start.round().toString(),
                        edadRange.end.round().toString(),
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          edadRange = values;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // ¿Qué géneros participan?
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¿Qué géneros participan?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Opciones: Hombres, Mujeres, Todo el mundo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ChoiceChip(
                          label: const Text('Hombres'),
                          labelStyle: TextStyle(
                              color: generoSeleccionado == 0
                                  ? Colors.black
                                  : Colors.white),
                          selected: generoSeleccionado == 0,
                          selectedColor: Colors.white,
                          onSelected: (_) {
                            setState(() {
                              generoSeleccionado = 0;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Mujeres'),
                          labelStyle: TextStyle(
                              color: generoSeleccionado == 1
                                  ? Colors.black
                                  : Colors.white),
                          selected: generoSeleccionado == 1,
                          selectedColor: Colors.white,
                          onSelected: (_) {
                            setState(() {
                              generoSeleccionado = 1;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Todo el mundo'),
                          labelStyle: TextStyle(
                              color: generoSeleccionado == 2
                                  ? Colors.black
                                  : Colors.white),
                          selected: generoSeleccionado == 2,
                          selectedColor: Colors.white,
                          onSelected: (_) {
                            setState(() {
                              generoSeleccionado = 2;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Botones de acción: Cancelar y Aplicar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
                          ),
                          onPressed: _aplicarFiltros,
                          child: const Text(
                            'Aceptar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Función para mostrar el pop up desde cualquier parte de la app.
Future<Map<String, dynamic>?> showExploreFilterDialog(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(10),
      child: ExploreScreenFilterDialog(),
    ),
  );
}
