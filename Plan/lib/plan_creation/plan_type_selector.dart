import 'package:flutter/material.dart';

class PlanTypeSelector extends StatefulWidget {
  final ValueChanged<String?> onSelected;

  const PlanTypeSelector({
    Key? key,
    required this.onSelected,
  }) : super(key: key);

  @override
  _PlanTypeSelectorState createState() => _PlanTypeSelectorState();
}

class _PlanTypeSelectorState extends State<PlanTypeSelector> {
  String? selectedValue;

  // Tipos de planes con iconos
  final Map<String, IconData> _planTypes = {
    'Cultural': Icons.museum,
    'Deportivo': Icons.run_circle,
    'Social': Icons.group,
    'Educativo': Icons.school,
    'Cine': Icons.movie,
    'Música': Icons.music_note,
    'Naturaleza': Icons.park,
    'Viaje': Icons.flight,
    'Tecnología': Icons.computer,
    'Gastronomía': Icons.restaurant,
    'Literatura': Icons.book,
    'Arte': Icons.palette,
    'Fiesta': Icons.celebration,
    'Voluntariado': Icons.volunteer_activism,
    'Salud y Bienestar': Icons.fitness_center,
    'Deportes Acuáticos': Icons.pool,
    'Fotografía': Icons.camera_alt,
    'Juegos de Mesa': Icons.casino,
    'Videojuegos': Icons.videogame_asset,
    'Senderismo': Icons.hiking,
    'Otros': Icons.more_horiz,
  };

  void _showCustomDropdown(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Bordes redondeados
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300), // Altura limitada a 7 elementos aprox.
            child: ListView(
              children: _planTypes.keys.map((type) {
                return ListTile(
                  leading: Icon(
                    _planTypes[type] ?? Icons.more_horiz,
                    color: Colors.blue,
                  ),
                  title: Text(type),
                  onTap: () {
                    setState(() {
                      selectedValue = type;
                    });
                    widget.onSelected(type);
                    Navigator.pop(context); // Cierra el menú emergente
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCustomDropdown(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30), // Bordes redondeados
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (selectedValue != null)
                  Icon(
                    _planTypes[selectedValue],
                    color: Colors.blue,
                  ),
                if (selectedValue != null) const SizedBox(width: 8),
                Text(
                  selectedValue ?? 'Selecciona el tipo de plan',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_drop_down_circle,
              color: Colors.blue, // Ícono con estilo azul
            ),
          ],
        ),
      ),
    );
  }
}
