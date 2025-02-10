import 'dart:ui'; // para BackdropFilter
import 'package:dating_app/main/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'users_managing/user_info_check.dart';

// Importa tu fichero de opciones
import 'options_for_plans.dart';

class UsersGrid extends StatelessWidget {
  final void Function(dynamic userDoc)? onUserTap;
  final List<dynamic> users;

  const UsersGrid({
    super.key,
    required this.users,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final userDoc = users[index];
        final Map<String, dynamic> userData = userDoc is QueryDocumentSnapshot
            ? (userDoc.data() as Map<String, dynamic>)
            : userDoc as Map<String, dynamic>;

        return _buildUserCard(userData, context);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> userData, BuildContext context) {
    final name = userData['name']?.toString().trim() ?? 'Usuario';
    final age = userData['age']?.toString() ?? '--';
    final photoUrl = userData['photoUrl']?.toString();
    final userHandle = userData['handle']?.toString() ?? '@usuario';
    final caption =
        userData['caption']?.toString() ?? 'Descripción breve o #hashtags';
    final likesCount = '1245';
    final commentsCount = '173';
    final sharesCount = '227';

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: 330,
        margin: const EdgeInsets.only(bottom: 15),
        child: Stack(
          children: [
            // Imagen de fondo (sin interacción).
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            // -----------------------------------------
            // 1) Avatar + nombre (tap -> UserInfoCheck)
            // -----------------------------------------
            Positioned(
              top: 10,
              left: 10,
              child: GestureDetector(
                onTap: () {
                  final String? uid = userData['uid']?.toString();
                  if (uid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserInfoCheck(userId: uid),
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: const Color.fromARGB(255, 14, 14, 14)
                          .withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildProfileAvatar(photoUrl),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SvgPicture.asset(
                                    'assets/verificado.svg',
                                    width: 14,
                                    height: 14,
                                    color: Colors.blueAccent,
                                  ),
                                ],
                              ),
                              Text(
                                userHandle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // -----------------------------------------
            // 2) Menú (3 puntos) con GlobalKey
            // -----------------------------------------
            Positioned(
              top: 16,
              right: 16,
              child: _buildThreeDotsMenu(userData),
            ),

            // -----------------------------------------
            // 3) Contadores + caption (parte inferior)
            // -----------------------------------------
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      // Gradiente vertical: transparente arriba, oscuro (negro) abajo
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // FILA SUPERIOR: iconos de corazon, comentario, compartir
                        // + contador de participantes en la esquina derecha.
                        Row(
                          children: [
                            _buildIconText(
                              icon: Icons.favorite_border,
                              label: likesCount,
                            ),
                            const SizedBox(width: 25),
                            _buildIconText(
                              icon: Icons.chat_bubble_outline,
                              label: commentsCount,
                            ),
                            const SizedBox(width: 25),
                            _buildIconText(
                              icon: Icons.share,
                              label: sharesCount,
                            ),

                            // Empujamos el contenido para la derecha
                            const Spacer(),

                            // Contador de participantes y el icono "users.svg"
                            Row(
                              children: [
                                Text(
                                  '7/10', // Dato dummy
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SvgPicture.asset(
                                  'assets/users.svg',
                                  color: AppColors.blue,
                                  width: 20,
                                  height: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // FILA INFERIOR: solo el texto de caption
                        Text(
                          caption,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// Construimos un widget aparte para manejar el 3-puntitos con GlobalKey.
  Widget _buildThreeDotsMenu(Map<String, dynamic> userData) {
    // Creamos el key en cada tarjeta para poder obtener la posición exacta
    final GlobalKey iconKey = GlobalKey();

    return InkWell(
      key: iconKey,
      onTap: () {
        // Al pulsar, obtenemos la posición y tamaño global del icono
        final renderBox = iconKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final offset = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        // Ahora llamamos a la función que muestra el menú,
        // pasándole offset + size.
        showPlanOptions(
          iconKey.currentContext!, // El BuildContext
          userData,                // Datos de la tarjeta/plan
          offset,                  // Posición global
          size,                    // Tamaño del botón
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: const Color.fromARGB(255, 14, 14, 14).withOpacity(0.1),
            padding: const EdgeInsets.all(10),
            child: const Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------
  //  Avatares, placeholders e iconos repetitivos
  // -----------------------------------------------
  Widget _buildProfileAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(photoUrl),
      );
    } else {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      );
    }
  }

  Widget _buildPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.grey[200],
        height: 350,
        width: double.infinity,
        child: const Center(
          child: Icon(Icons.person, size: 40, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildIconText({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
