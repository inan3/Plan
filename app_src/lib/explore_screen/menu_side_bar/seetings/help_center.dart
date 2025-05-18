import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Pantalla de Centro de Ayuda con buscador y preguntas frecuentes.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  /// Lista de preguntas y respuestas que se muestran en la pantalla.
  final List<Map<String, String>> _faqs = [
    {
      'q': '¿Cómo creo un nuevo plan?',
      'a': '1. Toca el botón “+” para abrir el formulario de creación de plan.\n'
          '2. Selecciona o escribe el tipo de plan en el selector.\n'
          '3. Añade hasta 3 imágenes o 1 vídeo tocando en “Contenido multimedia” y elige desde galería o cámara (vídeo máximo 15 s).\n'
          '4. Pulsa “Fecha y hora del plan” para escoger fecha(s) y hora(s); marca “Todo el día” o “Incluir fecha final” si lo deseas.\n'
          '5. Selecciona el punto de encuentro en el mapa para fijar la ubicación.\n'
          '6. Ajusta la restricción de edad con el control deslizante y define el número máximo de participantes.\n'
          '7. Escribe una breve descripción del plan.\n'
          '8. Elige la visibilidad (Público, Privado o Solo para mis seguidores).\n'
          '9. Finalmente pulsa “Finalizar Plan” y tu plan se publicará. Puedes ver tu plan en la sección “Mis planes” y compartirlo con amigos.'
    },
    {
      'q': '¿Cómo busco planes cerca de mí?',
      'a': '1. Abre la sección Explorar tocando el icono de la casa en la barra inferior.\n'
          '2. La lista de usuarios se ordena por proximidad usando tu ubicación y la función computeDistance.\n'
          '3. Ajusta filtros: toca el ícono de embudo para filtrar por edad o distancia.\n'
          '4. Si prefieres un mapa, toca el icono de mapa en la barra inferior para ver marcadores de usuarios con planes públicos.\n'
          '5. Pulsa un marcador o un perfil en la lista para ver sus planes (PlanCard) y unirte.'
    },
    {
      'q': '¿Cómo invito a alguien a un plan?',
      'a': '1. En el perfil de un usuario sin planes, toca el botón “Invítale a un Plan”.\n'
          '2. Elige “Existente” para seleccionar uno de tus planes activos o “Nuevo” para crear un plan privado.\n'
          '3. Si seleccionas Existente, escoge un plan de la lista y confirma la invitación en el diálogo.\n'
          '4. Si seleccionas Nuevo, completa el formulario rápido de plan privado (tipo, fecha, ubicación y descripción) y finaliza.\n'
          '5. Al confirmar, se envía una notificación al usuario invitado y verás un mensaje de éxito.'
    },
    {
      'q': '¿Qué es un plan privado?',
      'a': 'Un plan privado solo es visible para ti y para las personas con quien lo compartes. '
          'Nadie más podrá verlo ni unirse.'
    },
    {
      'q': '¿Cómo funciona el mapa?',
      'a': 'El mapa muestra todos los planes públicos con los que puedes interactuar y unirte si lo deseas. '
          'Puedes ver la ubicación de los planes en el mapa y tocar los marcadores para ver más detalles sobre cada plan. '
          'Además, puedes filtrar los planes según tus intereses y preferencias. '
          'Puedes acercar, alejar y mover el mapa para ver planes en todo el mundo.'
    },
    // NUEVA PREGUNTA AÑADIDA
    {
      'q': '¿Cómo funcionan los niveles de privilegio?',
      'a': 'Los niveles definen ventajas y herramientas adicionales según tu actividad en la app:\n'
          '\n'
          '**Básico**\n'
          '• Crear 1 plan activo a la vez.\n'
          '• Unirse a planes públicos sin límite.\n'
          '• Chat básico dentro del plan.\n'
          '• Soporte mediante FAQ y correo.\n'
          '\n'
          '**Premium**\n'
          '• Todo lo anterior y más funciones para mejorar tu experiencia:\n'
          '• Crear hasta 3 planes activos a la vez y opción de planes recurrentes (p. ej. todos los viernes).\n'
          '• Añadir hasta 10 fotos + 1 vídeo largo (30 s) para promocionar tus planes.\n'
          '• Co-organizadores: asigna a 1 persona para ayudarte a gestionar el plan.\n'
          '• Notificaciones push personalizadas (elige cuándo se envían recordatorios).\n'
          '\n'
          '**Golden**\n'
          '• Crear eventos con precio (ticketing in-app); la app cobra la comisión estándar.\n'
          '• Combinar cuenta como usuario normal y empresa creadora de planes/eventos.\n'
          '• Crear planes ilimitados activos a la vez.\n'
          '• Configurar admisión de participantes basada en su nivel de privilegio (p. ej. solo usuarios Golden/VIP pueden participar).\n'
          '• Destacar tu plan (“boost”) 1 vez por semana para aparecer arriba en la lista y con pin dorado en el mapa.\n'
          '• Analítica: ver quién ha visitado tus planes, tasa de confirmación y mapa de calor de intereses.\n'
          '• Atención al cliente por chat con respuesta en menos de 24 horas.\n'
          '\n'
          '**VIP**\n'
          '• Todos los beneficios anteriores sin límites + prioridad absoluta en el algoritmo de descubrimiento.\n'
          '• Marca verificada (insignia) y URL corta única para compartir planes.\n'
          '• Posibilidad de patrocinar planes (tu logo visible en portada de la sección Explorar).\n'
          '• Múltiples co-organizadores y roles personalizados (moderador, fotógrafo, etc.).\n'
          '• Dashboard avanzado con exportación CSV y reportes mensuales.\n'
          '• Atención al cliente en tiempo real y acceso anticipado a funcionalidades beta.'
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
            Center(
              child: Image.asset(
                'assets/plan-sin-fondo.png',
                height: 80,
              ),
            ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 16),
            const Text(
              'Preguntas más frecuentes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            // Contenedor de FAQs
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: filtered.map((item) {
                  return Column(
                    children: [
                      ListTile(
                        leading: SvgPicture.asset(
                          'assets/icono-preguntas.svg',
                          width: 24,
                          height: 24,
                        ),
                        title: Text(
                          item['q']!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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

/// Pantalla de detalle para mostrar la respuesta completa de una FAQ.
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
        title: Text(
          question,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          answer,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
