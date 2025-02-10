import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart'; // Asegúrate de haber agregado la dependencia en pubspec.yaml
import '../main/colors.dart'; // Asegúrate de tener definido AppColors
import '../main/keys.dart';  // Debe contener las claves: APIKeys.androidApiKey y APIKeys.iosApiKey

class ExploreScreenFilterDialog extends StatefulWidget {
  const ExploreScreenFilterDialog({Key? key}) : super(key: key);

  @override
  _ExploreScreenFilterDialogState createState() =>
      _ExploreScreenFilterDialogState();
}

class _ExploreScreenFilterDialogState extends State<ExploreScreenFilterDialog>
    with SingleTickerProviderStateMixin {
  // Variables de filtro
  String planBusqueda = ''; // Para búsqueda por nombre o descripción
  String? planPredeterminado; // Para seleccionar de una lista predeterminada
  // Lista de planes predeterminados de ejemplo
  final List<String> tiposPlan = ['Deportivo', 'Cultural', 'Social', 'Otro'];

  // Variables de región
  String regionBusqueda = '';
  // Controlador para el input de región (con autocompletado)
  final TextEditingController _regionController = TextEditingController();
  List<dynamic> _regionPredictions = [];

  // Variable para indicar si se ha concedido la ubicación actual
  bool locationAllowed = false;

  // Rango de edad (valor mínimo y máximo)
  RangeValues edadRange = const RangeValues(18, 60);

  // Género seleccionado: 0 - Hombres, 1 - Mujeres, 2 - Todo el mundo
  int generoSeleccionado = 2;

  // AnimationController para el efecto animado en el título
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // Configuramos la animación para que dure 2 segundos y se repita en modo reversible.
    _animationController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat(reverse: true);
  }

  // Método auxiliar para construir el botón de género con parámetros opcionales borderRadius y width
  Widget _buildGenderButton(String label, int value,
      {double borderRadius = 10.0, double? width}) {
    bool isSelected = (generoSeleccionado == value);
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          setState(() {
            generoSeleccionado = value;
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: width ?? double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.blue : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget separador elegante (línea fina blanca continua)
  Widget _buildElegantDivider() {
    return Divider(
      color: Colors.white,
      thickness: 0.2,
      height: 20,
    );
  }

  // Widget animado para el título "Filtrar Planes"
  Widget _buildAnimatedTitle() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            // Definimos un gradiente que se desplaza en función del valor de la animación.
            double animValue = _animationController.value;
            return LinearGradient(
              colors: [AppColors.blue, Colors.white, AppColors.blue],
              stops: [
                (animValue - 0.1).clamp(0.0, 1.0),
                animValue.clamp(0.0, 1.0),
                (animValue + 0.1).clamp(0.0, 1.0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds);
          },
          child: child,
          blendMode: BlendMode.srcIn,
        );
      },
      child: const Text(
        'Filtrar Planes',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white, // Este color será sobrescrito por el ShaderMask
        ),
      ),
    );
  }

  // Función para simular obtener la ubicación actual (en una implementación real usarías geolocalización)
  void _obtenerUbicacion() {
    setState(() {
      regionBusqueda = 'Ubicación actual';
      _regionController.text = regionBusqueda;
      _regionPredictions = [];
    });
  }

  // Función para pedir permiso de ubicación y, en caso afirmativo, obtener la ubicación actual
  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      setState(() {
        locationAllowed = true;
      });
      _obtenerUbicacion();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        locationAllowed = false;
      });
      // Muestra un diálogo para que el usuario vaya a la configuración
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permiso de ubicación'),
          content: const Text(
              'El permiso de ubicación ha sido denegado permanentemente. Por favor, ve a la configuración de la app para habilitarlo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Configuración'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        locationAllowed = false;
      });
      // Si es denegado temporalmente, podrías notificar al usuario o simplemente no hacer nada.
    }
  }

  // Función para obtener predicciones de lugares desde Google Places
  Future<void> _fetchRegionPredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _regionPredictions = [];
      });
      return;
    }
    // Selecciona la clave adecuada según la plataforma
    final String key = Platform.isAndroid ? APIKeys.androidApiKey : APIKeys.iosApiKey;
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$key&language=es';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _regionPredictions = data['predictions'];
          });
        } else {
          print('Error en la API de Google Places: ${data['status']}');
        }
      } else {
        print('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener predicciones: $e');
    }
  }

  // Cuando se selecciona una predicción, se actualiza el campo de región
  void _onRegionPredictionTap(dynamic prediction) {
    setState(() {
      regionBusqueda = prediction['description'];
      _regionController.text = regionBusqueda;
      _regionPredictions = [];
    });
  }

  void _aplicarFiltros() {
    // Se pasan los valores del filtro a la pantalla Explore para filtrar los planes.
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
  void dispose() {
    _animationController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Contenedor de pantalla completa para detectar toques fuera del popup y cerrar el diálogo.
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Al tocar fuera del popup se cierra el diálogo
        onTap: () {
          Navigator.of(context).pop();
        },
        child: Center(
          // GestureDetector interno para evitar que toques dentro del popup cierren el diálogo.
          child: GestureDetector(
            onTap: () {},
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
                        // Título animado
                        _buildAnimatedTitle(),
                        _buildElegantDivider(),
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
                        // Dropdown para planes predeterminados
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            labelText: 'Tipo de plan',
                            labelStyle: const TextStyle(
                                color: Color.fromARGB(255, 207, 193, 193)),
                          ),
                          dropdownColor: AppColors.blue,
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
                        // Separador entre dropdown y búsqueda por nombre:
                        Center(
                          child: Text(
                            '- o -',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Campo de búsqueda por nombre o descripción:
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.2),
                            hintText: 'Busca por nombre...',
                            hintStyle: const TextStyle(
                                color: Color.fromARGB(255, 207, 193, 193)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onChanged: (value) {
                            planBusqueda = value;
                          },
                        ),
                        _buildElegantDivider(),
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
                        // Campo de región con autocompletado y botón de "Tu ubicación actual"
                        Column(
                          children: [
                            TextField(
                              controller: _regionController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.2),
                                hintText: 'Ciudad, país o radio (km)',
                                hintStyle: const TextStyle(
                                    color: Color.fromARGB(255, 207, 193, 193)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.my_location,
                                      color: Colors.white),
                                  onPressed: _obtenerUbicacion,
                                ),
                              ),
                              onChanged: (value) {
                                // Actualiza el filtro de región y obtiene predicciones
                                setState(() {
                                  regionBusqueda = value;
                                });
                                _fetchRegionPredictions(value);
                              },
                            ),
                            const SizedBox(height: 10),
                            // Separador entre el campo de dirección y el botón
                            Center(
                              child: Text(
                                '- o -',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Botón elegante para "Tu ubicación actual"
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: locationAllowed
                                    ? AppColors.blue
                                    : AppColors.blue.withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: _requestLocationPermission,
                              child: const Text(
                                'Tu ubicación actual',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ),
                            // Lista de predicciones con efecto frosted glass:
                            if (_regionPredictions.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 5),
                                    padding: const EdgeInsets.all(5),
                                    color: Colors.white.withOpacity(0.2),
                                    constraints:
                                        const BoxConstraints(maxHeight: 150),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _regionPredictions.length,
                                      itemBuilder: (context, index) {
                                        final prediction =
                                            _regionPredictions[index];
                                        return ListTile(
                                          title: Text(
                                            prediction['description'],
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                          onTap: () =>
                                              _onRegionPredictionTap(prediction),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        _buildElegantDivider(),
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
                        // RangeSlider para el rango de edad
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
                        _buildElegantDivider(),
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
                        // Botones verticales para elegir género
                        Column(
                          children: [
                            _buildGenderButton("Hombres", 0,
                                borderRadius: 30, width: 200),
                            const SizedBox(height: 10),
                            _buildGenderButton("Mujeres", 1,
                                borderRadius: 30, width: 200),
                            const SizedBox(height: 10),
                            _buildGenderButton("Todo el mundo", 2,
                                borderRadius: 30, width: 200),
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
