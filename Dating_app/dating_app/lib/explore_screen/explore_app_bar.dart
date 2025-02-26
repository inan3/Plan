import 'dart:ui';
import 'package:flutter/material.dart';
import '../main/colors.dart';
import 'notification_screen.dart';

class ExploreAppBar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationPressed;
  final ValueChanged<String> onSearchChanged;
  final Stream<int>? notificationCountStream;

  const ExploreAppBar({
    super.key,
    required this.onMenuPressed,
    required this.onNotificationPressed,
    required this.onSearchChanged,
    this.notificationCountStream,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Botón de Menú a la izquierda
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 92, 92, 92)
                            .withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(5, 5),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Image.asset(
                      'assets/menu.png',
                      color: AppColors.blue,
                      width: 18,
                      height: 18,
                    ),
                    onPressed: onMenuPressed,
                  ),
                ),
              ),
            ),
          ),

          // Logo
          Transform.translate(
            offset: const Offset(0, 0),
            child: Image.asset(
              'assets/plan-sin-fondo.png',
              height: 80,
            ),
          ),

          // Contenedor para el botón de notificación en la derecha
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 92, 92, 92)
                                .withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(5, 5),
                          ),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Image.asset(
                              'assets/notificacion.png',
                              color: AppColors.blue,
                              width: 20,
                              height: 20,
                            ),
                            onPressed: onNotificationPressed,
                          ),
                          // Badge de notificaciones
                          if (notificationCountStream != null)
                            Positioned(
                              right: 11,
                              top: 10,
                              child: StreamBuilder<int>(
                                stream: notificationCountStream,
                                builder: (context, snapshot) {
                                  final count = snapshot.data ?? 0;
                                  if (count == 0) return const SizedBox();
                                  return Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 13,
                                      minHeight: 13,
                                    ),
                                    child: Center(
                                      child: Text(
                                        count > 9 ? '9+' : '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
