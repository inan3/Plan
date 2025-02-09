import 'dart:ui'; // para BackdropFilter
import 'package:dating_app/main/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      // Se elimina el padding para que el primer usuario quede en el borde superior.
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final userDoc = users[index];
        // Verifica si el elemento es un QueryDocumentSnapshot o un Map (dummy)
        final Map<String, dynamic> userData = userDoc is QueryDocumentSnapshot
            ? (userDoc.data() as Map<String, dynamic>)
            : userDoc as Map<String, dynamic>;

        return GestureDetector(
          onTap: () => onUserTap?.call(userDoc),
          child: _buildUserCard(userData, context),
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> userData, BuildContext context) {
    final name = userData['name']?.toString().trim() ?? 'Usuario';
    final age = userData['age']?.toString() ?? '--';
    final photoUrl = userData['photoUrl']?.toString();
    // Datos opcionales.
    final userHandle = userData['handle']?.toString() ?? '@usuario';
    final caption =
        userData['caption']?.toString() ?? 'Descripción breve o #hashtags';
    final likesCount = '1245';
    final commentsCount = '173';
    final sharesCount = '227';

    return Center(
      // Reducimos el ancho al 90% del ancho de la pantalla.
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: 330, // Altura de la tarjeta.
        margin: const EdgeInsets.only(bottom: 15),
        child: Stack(
          children: [
            // Imagen de fondo con bordes redondeados.
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            // FROSTED GLASS en la parte superior izquierda con avatar y nombre.
            Positioned(
              top: 10,
              left: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: const Color.fromARGB(255, 14, 14, 14)
                        .withOpacity(0.2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
            // FROSTED GLASS en la parte superior derecha con menú (3 puntos).
            Positioned(
              top: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: const Color.fromARGB(255, 14, 14, 14)
                        .withOpacity(0.1),
                    padding: const EdgeInsets.all(10),
                    child: InkWell(
                      onTap: () {
                        // Acción para menú de opciones.
                      },
                      child: const Icon(
                        Icons.more_vert,
                        color: AppColors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Capa inferior con fondo oscuro, contadores y caption.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      ],
                    ),
                    const SizedBox(height: 8),
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
          ],
        ),
      ),
    );
  }

  /// Widget para el avatar.
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

  /// Placeholder para la imagen de fondo.
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

  /// Construye un widget con un icono y texto.
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
