import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;

// Importaciones necesarias:
import '../users_managing/user_info_check.dart';
import '../plans_managing/plan_card.dart'; // <--- Asegúrate de importar tu PlanCard
import '../plans_managing/firebase_services.dart'; // <--- Para fetchPlanParticipants, si lo tienes
import '../plans_managing/frosted_plan_dialog_state.dart';
import '../../l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NotificationScreen extends StatefulWidget {
  final String currentUserId;
  const NotificationScreen({Key? key, required this.currentUserId})
      : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Trae todas las notificaciones del usuario actual
  Stream<QuerySnapshot> _getAllNotifications() {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: widget.currentUserId)
        .snapshots();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final dateTime = (timestamp as Timestamp).toDate();
    return DateFormat('HH:mm').format(dateTime);
  }

  //-----------------------------------------------------------------------
  // Aceptar join_request
  //-----------------------------------------------------------------------
  Future<void> _handleAcceptJoinRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final senderId = data['senderId'] as String;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina notificación
      await doc.reference.delete();

      // Agrega el sender a la lista de participantes
      final planRef = _firestore.collection('plans').doc(planId);
      final planDoc = await planRef.get();
      if (!planDoc.exists) return;

      await planRef.update({
        'participants': FieldValue.arrayUnion([senderId]),
      });

      // Crea la suscripción (guardamos también el id del plan)
      await _firestore.collection('subscriptions').add({
        ...planDoc.data()!,
        'id': planId,
        'userId': senderId,
        'subscriptionDate': FieldValue.serverTimestamp(),
      });

      // Notifica al sender
      final acceptorDoc =
          await _firestore.collection('users').doc(widget.currentUserId).get();

      final acceptorPhoto =
          acceptorDoc.exists ? (acceptorDoc.data()!['photoUrl'] ?? '') : '';
      final acceptorName =
          acceptorDoc.exists ? (acceptorDoc.data()!['name'] ?? '') : '';

      await _firestore.collection('notifications').add({
        'type': 'join_accepted',
        'receiverId': senderId,
        'senderId': widget.currentUserId,
        'planId': planId,
        'planName': planType,
        'senderProfilePic': acceptorPhoto,
        'senderName':
            acceptorName, // <--- Importante para que se muestre el nombre
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar solicitud: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Rechazar join_request
  //-----------------------------------------------------------------------
  Future<void> _handleRejectJoinRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final senderId = data['senderId'] as String;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina la notificación
      await doc.reference.delete();

      // Notifica al que pidió unirse
      final rejectorDoc =
          await _firestore.collection('users').doc(widget.currentUserId).get();
      final rejectorPhoto =
          rejectorDoc.exists ? (rejectorDoc.data()!['photoUrl'] ?? '') : '';
      final rejectorName =
          rejectorDoc.exists ? (rejectorDoc.data()!['name'] ?? '') : '';

      await _firestore.collection('notifications').add({
        'type': 'join_rejected',
        'receiverId': senderId,
        'senderId': widget.currentUserId,
        'planId': planId,
        'planName': planType,
        'senderProfilePic': rejectorPhoto,
        'senderName': rejectorName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar solicitud: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Aceptar invitación
  //-----------------------------------------------------------------------
  Future<void> _handleAcceptInvitation(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final creatorId = data['senderId'] as String;
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina la notificación
      await doc.reference.delete();

      // Agrega al usuario actual al plan solo si estaba invitado
      final planRef = _firestore.collection('plans').doc(planId);
      final planDoc = await planRef.get();
      if (!planDoc.exists) return;

      final List<dynamic> invited = planDoc.data()?["invitedUsers"] ?? [];
      if (!invited.contains(currentUserId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No estás invitado a este plan.')),
        );
        return;
      }

      await planRef.update({
        'participants': FieldValue.arrayUnion([currentUserId]),
        'invitedUsers': FieldValue.arrayRemove([currentUserId]),
      });

      // Crea la suscripción (guardamos también el id del plan)
      await _firestore.collection('subscriptions').add({
        ...planDoc.data()!,
        'id': planId,
        'userId': currentUserId,
        'subscriptionDate': FieldValue.serverTimestamp(),
      });

      // Notifica al creador
      final acceptorDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      final acceptorPhoto =
          acceptorDoc.exists ? (acceptorDoc.data()!['photoUrl'] ?? '') : '';
      final acceptorName =
          acceptorDoc.exists ? (acceptorDoc.data()!['name'] ?? '') : '';

      await _firestore.collection('notifications').add({
        'type': 'invitation_accepted',
        'receiverId': creatorId,
        'senderId': currentUserId,
        'planId': planId,
        'planName': planType,
        'senderProfilePic': acceptorPhoto,
        'senderName': acceptorName, // <--- Importante para mostrar el nombre
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar invitación: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Rechazar invitación
  //-----------------------------------------------------------------------
  Future<void> _handleRejectInvitation(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final creatorId = data['senderId'] as String;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Elimina la notificación
      await doc.reference.delete();

      // Elimina al usuario de la lista de invitados
      await _firestore.collection('plans').doc(planId).update({
        'invitedUsers': FieldValue.arrayRemove([currentUserId]),
      });

      // Notifica al creador
      final rejectorDoc =
          await _firestore.collection('users').doc(widget.currentUserId).get();
      final rejectorPhoto =
          rejectorDoc.exists ? (rejectorDoc.data()!['photoUrl'] ?? '') : '';
      final rejectorName =
          rejectorDoc.exists ? (rejectorDoc.data()!['name'] ?? '') : '';

      await _firestore.collection('notifications').add({
        'type': 'invitation_rejected',
        'receiverId': creatorId,
        'senderId': widget.currentUserId,
        'planId': planId,
        'planName': planType,
        'senderProfilePic': rejectorPhoto,
        'senderName': rejectorName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar invitación: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Eliminar notificación
  //-----------------------------------------------------------------------
  Future<void> _handleDeleteNotification(DocumentSnapshot doc) async {
    await doc.reference.delete();
  }

  //-----------------------------------------------------------------------
  // Aceptar solicitud de seguimiento (follow_request)
  //-----------------------------------------------------------------------
  Future<void> _handleAcceptFollowRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;
      final receiverId = data['receiverId'] as String;

      // Elimina la notificación de follow_request
      await doc.reference.delete();

      // Actualiza las colecciones 'followers' y 'followed'
      await _firestore.collection('followers').add({
        'userId': receiverId,
        'followerId': senderId,
      });
      await _firestore.collection('followed').add({
        'userId': senderId,
        'followedId': receiverId,
        // por defecto, asumimos notifyOnNewPlan: false
        'notifyOnNewPlan': false,
      });

      // Notifica al sender que ha sido aceptado
      final acceptorDoc =
          await _firestore.collection('users').doc(receiverId).get();
      final acceptorPhoto =
          acceptorDoc.exists ? (acceptorDoc.data()!['photoUrl'] ?? '') : '';
      final acceptorName =
          acceptorDoc.exists ? (acceptorDoc.data()!['name'] ?? '') : '';

      await _firestore.collection('notifications').add({
        'type': 'follow_accepted',
        'receiverId': senderId,
        'senderId': receiverId,
        'senderProfilePic': acceptorPhoto,
        'senderName': acceptorName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar solicitud de follow: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Rechazar solicitud de seguimiento
  //-----------------------------------------------------------------------
  Future<void> _handleRejectFollowRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;
      final receiverId = data['receiverId'] as String;

      // Elimina la notificación de follow_request
      await doc.reference.delete();

      // Notifica al que pidió follow que fue rechazado
      final rejectorDoc =
          await _firestore.collection('users').doc(receiverId).get();
      final rejectorPhoto =
          rejectorDoc.exists ? (rejectorDoc.data()!['photoUrl'] ?? '') : '';
      final rejectorName =
          rejectorDoc.exists ? (rejectorDoc.data()!['name'] ?? '') : '';

      await _firestore.collection('notifications').add({
        'type': 'follow_rejected',
        'receiverId': senderId,
        'senderId': receiverId,
        'senderProfilePic': rejectorPhoto,
        'senderName': rejectorName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar solicitud de follow: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Al pulsar una notificación, abrimos la PlanCard con UI coherente
  //-----------------------------------------------------------------------
  Future<void> _showPlanDetails(BuildContext context, String planId) async {
    final planDoc = await _firestore.collection('plans').doc(planId).get();
    if (!planDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El plan ya no existe.')),
      );
      return;
    }
    final planData = planDoc.data() as Map<String, dynamic>;
    final plan = PlanModel.fromMap(planData);

    {
      // Obtenemos el "userData" del creador, para pasárselo a PlanCard
      final creatorDoc =
          await _firestore.collection('users').doc(plan.createdBy).get();
      final Map<String, dynamic> creatorData =
          creatorDoc.exists ? creatorDoc.data() as Map<String, dynamic> : {};

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const ui.Color.fromARGB(255, 255, 255, 255),
            appBar: AppBar(
              title: const Text("Detalle del Plan"),
              backgroundColor: const ui.Color.fromARGB(221, 255, 255, 255),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  PlanCard(
                    plan: plan,
                    userData: creatorData,
                    fetchParticipants: _fetchAllPlanParticipants,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openPlanChatFromNotification(
      BuildContext context, String planId) async {
    final planDoc = await _firestore.collection('plans').doc(planId).get();
    if (!planDoc.exists) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El plan ya no existe.')));
      return;
    }
    final planData = planDoc.data() as Map<String, dynamic>;
    final plan = PlanModel.fromMap(planData);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrostedPlanDialog(
          plan: plan,
          fetchParticipants: _fetchAllPlanParticipants,
          openChat: true,
        ),
      ),
    );
  }

  //-----------------------------------------------------------------------
  // BUILD principal
  //-----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text("Debes iniciar sesión para ver notificaciones"),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título y botón atrás
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Notificaciones",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getAllNotifications(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildErrorWidget();
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoading();
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return _buildEmpty("No tienes notificaciones nuevas");
                      }

                      // Ordenar manualmente por timestamp descendente
                      docs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        final Timestamp tA =
                            dataA['timestamp'] as Timestamp? ?? Timestamp(0, 0);
                        final Timestamp tB =
                            dataB['timestamp'] as Timestamp? ?? Timestamp(0, 0);
                        return tB.compareTo(tA);
                      });

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final planType =
                              data['planType'] ?? data['planName'] ?? 'Plan';
                          final planId = data['planId'] ?? '';
                          final senderId = data['senderId'] ?? '';
                          final senderPhoto = data['senderProfilePic'] ?? '';
                          final senderName = data['senderName'] ?? '';
                          final type = data['type'] as String? ?? '';
                          final timestamp = data['timestamp'];
                          final timeString = _formatTimestamp(timestamp);

                          // Subtítulo con la hora
                          Widget buildSubtitle(String primaryText) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  primaryText,
                                  style: const TextStyle(color: AppColors.blue),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeString,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          }

                          // Botones [✗] y [✓]
                          Widget acceptRejectButtons({
                            required VoidCallback onAccept,
                            required VoidCallback onReject,
                          }) {
                            const bgColor = Color(0xFFF5F5F5);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 20,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    onPressed: onReject,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 20,
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    ),
                                    onPressed: onAccept,
                                  ),
                                ),
                              ],
                            );
                          }

                          // Avatar del sender
                          Widget leadingAvatar = GestureDetector(
                            onTap: () {
                              // Ir al perfil del sender
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserInfoCheck(userId: senderId),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 25,
                              backgroundImage: senderPhoto.isNotEmpty
                                  ? CachedNetworkImageProvider(senderPhoto)
                                  : CachedNetworkImageProvider(
                                      'https://cdn-icons-png.flaticon.com/512/847/847969.png',
                                    ),
                            ),
                          );

                          // Tipo de notificación
                          final isEn =
                              AppLocalizations.of(context).locale.languageCode ==
                                  'en';
                          switch (type) {
                            case 'join_request':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName wants to join one of your plans!'
                                      : '¡$senderName se quiere unir a un plan tuyo!'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                isThreeLine: true,
                                trailing: acceptRejectButtons(
                                  onAccept: () => _handleAcceptJoinRequest(doc),
                                  onReject: () => _handleRejectJoinRequest(doc),
                                ),
                              );
                            case 'join_accepted':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName has accepted you to join their plan!'
                                      : '¡$senderName ha aceptado que te unas a su plan!'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                isThreeLine: true, // ← Corregido
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'join_rejected':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName has rejected your request to join!'
                                      : '¡$senderName ha rechazado tu solicitud para unirte!'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                isThreeLine: true, // ← Corregido
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'invitation':
                              final int specialPlan = data['specialPlan'] ?? 0;
                              final String message = specialPlan == 1
                                  ? (isEn
                                      ? '$senderName has invited you to a special plan of $planType'
                                      : '$senderName te ha invitado a un plan especial de $planType')
                                  : (isEn
                                      ? '$senderName has invited you to join this plan!'
                                      : '¡$senderName te ha invitado a unirte a este plan!');
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(message),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                isThreeLine: true,
                                trailing: acceptRejectButtons(
                                  onAccept: () => _handleAcceptInvitation(doc),
                                  onReject: () => _handleRejectInvitation(doc),
                                ),
                              );
                            case 'invitation_accepted':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName accepted your invitation!'
                                      : '¡$senderName ha aceptado tu invitación!'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                isThreeLine: true,
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'invitation_rejected':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName rejected your invitation!'
                                      : '¡$senderName ha rechazado tu invitación!'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                isThreeLine: true,
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'follow_request':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName wants to follow you!'
                                      : '¡$senderName quiere seguirte!'
                                ),
                                subtitle: buildSubtitle("Solicitud de Follow"),
                                onTap: () {
                                  // Ir al perfil del sender
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserInfoCheck(userId: senderId),
                                    ),
                                  );
                                },
                                isThreeLine: true,
                                trailing: acceptRejectButtons(
                                  onAccept: () =>
                                      _handleAcceptFollowRequest(doc),
                                  onReject: () =>
                                      _handleRejectFollowRequest(doc),
                                ),
                              );
                            case 'follow_accepted':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName accepted your follow request!'
                                      : '¡$senderName ha aceptado tu solicitud de seguimiento!'
                                ),
                                subtitle:
                                    buildSubtitle("Ahora puedes ver su perfil"),
                                isThreeLine: true, // ← Corregido
                                onTap: () {
                                  // Ir al perfil de quien te aceptó
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserInfoCheck(userId: senderId),
                                    ),
                                  );
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'follow_rejected':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName rejected your follow request!'
                                      : '¡$senderName ha rechazado tu solicitud de seguimiento!'
                                ),
                                subtitle: buildSubtitle("Perfil privado"),
                                isThreeLine: true, // ← Corregido
                                onTap: () {
                                  // Ir al perfil de quien te rechazó
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserInfoCheck(userId: senderId),
                                    ),
                                  );
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'new_plan_published':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName has just published a plan. Check it out!'
                                      : '¡$senderName acaba de publicar un plan. Échale un vistazo!'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                isThreeLine: true, // ← Corregido
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'plan_chat_message':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName commented on the plan $planType'
                                      : '$senderName ha hecho un comentario sobre el plan $planType'
                                ),
                                subtitle: Text(
                                  timeString,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () => _openPlanChatFromNotification(
                                    context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'plan_left':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName has decided to leave your plan.'
                                      : '$senderName ha decidido abandonar tu plan.'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                isThreeLine: true,
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'special_plan_left':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName has decided to leave the special plan.'
                                      : '$senderName ha decidido abandonar el plan especial.'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                isThreeLine: true,
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'special_plan_deleted':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName has deleted the special plan.'
                                      : '$senderName ha eliminado el plan especial.'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                isThreeLine: true,
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'removed_from_plan':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? '$senderName removed you from their plan.'
                                      : '$senderName te ha eliminado de su plan.'
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                isThreeLine: true,
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'plan_checkin_started':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  isEn
                                      ? 'The organizer of the plan $planType has started the Check-in. Confirm your attendance.'
                                      : 'El organizador del plan $planType ha iniciado el Check-in. Confirma tu asistencia.',
                                ),
                                subtitle: buildSubtitle('Plan: $planType'),
                                isThreeLine: true,
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _handleDeleteNotification(doc),
                                ),
                              );
                            case 'welcome':
                              final String message = data['message'] ??
                                  '¡Bienvenido a Plan!';
                              return ListTile(
                                leading: const CircleAvatar(
                                  radius: 25,
                                  backgroundImage:
                                      AssetImage('assets/plan-sin-fondo.png'),
                                ),
                                title: Text(message),
                                subtitle: Text(
                                  timeString,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _handleDeleteNotification(doc),
                                ),
                              );
                            default:
                              return const SizedBox();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openFrostedPlanDialog(BuildContext context, PlanModel plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: FrostedPlanDialog(
            plan: plan,
            fetchParticipants: _fetchAllPlanParticipants,
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
    PlanModel plan,
  ) async {
    final List<Map<String, dynamic>> participants = [];
    final planDoc =
        await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (!planDoc.exists) return participants;

    final planData = planDoc.data()!;
    final participantUids = List<String>.from(planData['participants'] ?? []);
    final Set<String> processed = {};

    for (String uid in participantUids) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        participants.add({
          'uid': uid,
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': (plan.createdBy == uid),
        });
        processed.add(uid);
      }
    }

    if (!processed.contains(plan.createdBy)) {
      final creatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(plan.createdBy)
          .get();
      if (creatorDoc.exists && creatorDoc.data() != null) {
        final cData = creatorDoc.data()!;
        participants.add({
          'uid': plan.createdBy,
          'name': cData['name'] ?? 'Sin nombre',
          'age': cData['age']?.toString() ?? '',
          'photoUrl': cData['photoUrl'] ?? cData['profilePic'] ?? '',
          'isCreator': true,
        });
      }
    }

    return participants;
  }

  Widget _buildOverlappingAvatars(
    List<Map<String, dynamic>> participants,
    String currentUid,
  ) {
    if (participants.isEmpty) return const SizedBox.shrink();

    Widget buildAvatar(Map<String, dynamic> data) {
      final url = data['photoUrl'] ?? '';
      return CircleAvatar(
        radius: 20,
        backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      );
    }

    if (participants.length == 1) {
      return buildAvatar(participants.first);
    }

    Map<String, dynamic>? me;
    Map<String, dynamic>? other;
    for (var p in participants) {
      if (p['uid'] == currentUid && me == null) {
        me = p;
      } else if (other == null && p['uid'] != currentUid) {
        other = p;
      }
    }

    if (me == null || other == null) {
      return Row(
        children: participants.take(2).map(buildAvatar).toList(),
      );
    }

    return SizedBox(
      width: 64,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, child: buildAvatar(me)),
          Positioned(left: 24, child: buildAvatar(other)),
        ],
      ),
    );
  }

  //-----------------------------------------------------------------------
  // Widgets auxiliares
  //-----------------------------------------------------------------------
  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2.5),
      );

  Widget _buildErrorWidget() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 40),
            SizedBox(height: 10),
            Text(
              'Error al cargar datos',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ],
        ),
      );

  Widget _buildEmpty(String text) => Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
}
