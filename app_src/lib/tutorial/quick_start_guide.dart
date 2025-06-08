import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class QuickStartGuide {
  QuickStartGuide({required this.context, required this.addButtonKey});

  final BuildContext context;
  final GlobalKey addButtonKey;
  TutorialCoachMark? _tutorial;

  Future<void> show() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('quickStartShown') ?? false;

    // Siempre mostramos la guía para pruebas. Para la versión final
    // se debería comprobar `alreadyShown` antes de mostrarla.
    if (alreadyShown && false) return;

    _tutorial = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: 'Omitir',
      alignSkip: Alignment.topLeft,
      opacityShadow: 0.8,
      onFinish: () async {
        await prefs.setBool('quickStartShown', true);
      },
      onSkip: () async {
        await prefs.setBool('quickStartShown', true);
      },
    );

    _tutorial!.show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: 'add_button',
        keyTarget: addButtonKey,
        shape: ShapeLightFocus.circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(controller),
          ),
        ],
      ),
    ];
  }

  Widget _buildContent(TargetContentController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pinchando en el icono de + podrás crear un plan o evento.',
            style: TextStyle(color: Colors.white, fontSize: 18),
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
