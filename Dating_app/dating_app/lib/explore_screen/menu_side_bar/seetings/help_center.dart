import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final List<Map<String, String>> _faqs = [
    {
      'q': '¿Cómo creo un nuevo plan?',
      'a': 'Para crear un plan, pulsa el botón “+” en la parte inferior, '
           'elige detalles como título, fecha y ubicación, y confirma. Tu plan se publicará inmediatamente.'
    },
    {
      'q': '¿Cómo busco planes cerca de mí?',
      'a': 'En la pestaña Mapa, verás iconos de usuarios con planes cercanos. '
           'Pulsando uno accedes a su plan y puedes unirte.'
    },
    {
      'q': '¿Qué es un plan privado?',
      'a': 'Un plan privado solo es visible para ti y para la persona que invites. '
           'Nadie más podrá verlo ni unirse.'
    },
    {
      'q': '¿Cómo invito a alguien a un plan?',
      'a': 'En la pantalla de tu plan, toca “Invitar” y selecciona un usuario cercano o envía un enlace único.'
    },
    {
      'q': '¿Cómo funciona el mapa?',
      'a': 'El mapa muestra todos los planes públicos en tu región actual. '
           'Puedes acercar, alejar y mover el mapa para ver planes en otras áreas.'
    },
  ];

  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _faqs.where((item) {
      final text = (item['q']! + ' ' + item['a']!).toLowerCase();
      return text.contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de ayuda'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      backgroundColor: Colors.grey.shade200,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Center(child: Image.asset('assets/plan-sin-fondo.png', height: 80)),
            const SizedBox(height: 12),
            const Text(
              '¿En qué te puedo ayudar?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            // Buscador
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar en preguntas...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            const Text(
              'Preguntas más frecuentes',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            // Contenedor de FAQs
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: filtered.map((item) {
                  return Column(
                    children: [
                      ListTile(
                        leading: SvgPicture.asset('assets/icono-preguntas.svg', width: 24, height: 24),
                        title: Text(item['q']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _HelpDetailScreen(
                                question: item['q']!,
                                answer: item['a']!,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpDetailScreen extends StatelessWidget {
  final String question;
  final String answer;

  const _HelpDetailScreen({
    Key? key,
    required this.question,
    required this.answer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(answer, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
