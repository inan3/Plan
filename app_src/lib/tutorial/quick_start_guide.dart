//quick_start_guide.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuickStartGuide {
  QuickStartGuide({
    required this.context,
    required this.addButtonKey,
    required this.homeButtonKey,
    required this.mapButtonKey,
    required this.chatButtonKey,
    required this.profileButtonKey,
    required this.menuButtonKey,
    required this.notificationButtonKey,
    required this.searchBarKey,
    required this.userId,
  });

  final BuildContext context;
  final GlobalKey addButtonKey;
  final GlobalKey homeButtonKey;
  final GlobalKey mapButtonKey;
  final GlobalKey chatButtonKey;
  final GlobalKey profileButtonKey;
  final GlobalKey menuButtonKey;
  final GlobalKey notificationButtonKey;
  final GlobalKey searchBarKey;
  final String userId;
  TutorialCoachMark? _tutorial;

  Future<void> show() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'quickStartShown_$userId';
    final alreadyShown = prefs.getBool(key) ?? false;

    // Solo mostramos la guía si aún no se ha visto
    if (alreadyShown) return;

    _tutorial = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: '',
      alignSkip: Alignment.topRight,
      opacityShadow: 0.8,
      onFinish: () async {
        await prefs.setBool(key, true);
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'welcome',
          'receiverId': userId,
          'senderId': 'system',
          'senderName': 'Plan',
          'senderProfilePic': '',
          'message':
              'El equipo de Plan te da la bienvenida a la app que te conecta con nuevas experiencias y personas. ¡Comienza a explorar y a crear momentos inolvidables!',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      },
      onSkip: () {
        // Lanzar tareas asíncronas sin await
        SharedPreferences.getInstance()
            .then((prefs) => prefs.setBool(key, true));
        FirebaseFirestore.instance.collection('notifications').add({
          'type': 'welcome',
          'receiverId': userId,
          'senderId': 'system',
          'senderName': 'Plan',
          'senderProfilePic': '',
          'message':
              'El equipo de Plan te da la bienvenida a la app que te conecta con nuevas experiencias y personas. ¡Comienza a explorar y a crear momentos inolvidables!',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
        return true;
      },
    );

    _tutorial!.show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: 'add_button',
        keyTarget: addButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
                'Pinchando en el icono de + podrás crear un plan o evento.',
                controller),
          ),
        ],
      ),
      TargetFocus(
        identify: 'home_button',
        keyTarget: homeButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
                'En el icono de inicio verás los planes cercanos.', controller),
          ),
        ],
      ),
      TargetFocus(
        identify: 'map_button',
        keyTarget: mapButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
                'Con el mapa podrás localizar planes visualmente.', controller),
          ),
        ],
      ),
      TargetFocus(
        identify: 'chat_button',
        keyTarget: chatButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
                'Desde aquí accedes a tus conversaciones.', controller),
          ),
        ],
      ),
      TargetFocus(
        identify: 'profile_button',
        keyTarget: profileButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
              'En el perfil puedes ver y editar tu información.',
              controller,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'menu_button',
        keyTarget: menuButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildContent(
              'En este men\u00FA encontrar\u00E1s los planes que has creado o a los que te has suscrito, adem\u00E1s de los ajustes de tu cuenta.',
              controller,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'notification_button',
        keyTarget: notificationButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildContent(
              'Aqu\u00ED ver\u00E1s todas las notificaciones que recibas.',
              controller,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'search_bar',
        keyTarget: searchBarKey,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildContent(
              'Desde aqu\u00ED podr\u00E1s buscar o filtrar planes o usuarios.',
              controller,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildContent(String text, dynamic controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () => _tutorial?.skip(),
              child: const Text(
                'Omitir Tutorial',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: controller.next,
              child: const Text(
                'Siguiente',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
