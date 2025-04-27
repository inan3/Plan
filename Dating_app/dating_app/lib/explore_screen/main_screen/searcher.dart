import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/plan_model.dart';
import '../plans_managing/frosted_plan_dialog_state.dart'; // <-- Ajusta según tu proyecto
import '../users_managing/user_info_check.dart';

/// Representa un ítem de búsqueda, que puede ser un usuario o un plan.
class SearchResultItem {
  final String id; // uid de usuario o id del plan
  final String title; // nombre del usuario o "tipo" del plan
  final String subtitle; // edad, o fecha, etc.
  final String avatarUrl; // foto del usuario o avatar del creador del plan
  final bool isUser; // true => es un usuario, false => es un plan
  final PlanModel? planData; // si es un plan, se guarda aquí; sino null

  SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.isUser,
    this.planData,
  });
}

/// Widget que muestra la lista de resultados de búsqueda
/// debajo del campo de texto.
class Searcher extends StatefulWidget {
  final String query; // texto que introduce el usuario
  final double maxHeight; // altura máxima del contenedor de resultados
  final bool isVisible; // si mostramos u ocultamos por completo
  final Future<PlanModel> Function(String planId)? fetchFullPlanById;

  /// [fetchFullPlanById]: función opcional para reconstruir
  /// un PlanModel completo (ej. si quieres reutilizar la
  /// lógica que ya tienes en tu app). Si no la pasas, se usa
  /// una versión simple dentro del mismo widget.
  const Searcher({
    Key? key,
    required this.query,
    this.maxHeight = 300.0,
    this.isVisible = true,
    this.fetchFullPlanById,
  }) : super(key: key);

  @override
  State<Searcher> createState() => _SearcherState();
}

class _SearcherState extends State<Searcher> {
  bool _isLoading = false;
  List<SearchResultItem> _results = [];

  /// Guardamos el último texto de búsqueda para comparar en build()
  String _lastQuery = '';

  @override
  void didUpdateWidget(covariant Searcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newQuery = widget.query.trim();
    final oldQuery = oldWidget.query.trim();

    if (newQuery != oldQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(newQuery);
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() {
      _isLoading = true;
      _lastQuery = query;
    });

    try {
      final List<SearchResultItem> finalResults = [];

      // -------------------------------------------
      // 1) Buscar USUARIOS por nombre
      // -------------------------------------------
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + '\uf8ff')
          .get();

      for (var doc in usersQuery.docs) {
        final data = doc.data();
        final userId = data['uid'] ?? doc.id;
        final userName = data['name'] ?? 'Usuario';
        final userAge = data['age']?.toString() ?? '';
        final photoUrl = data['photoUrl'] ?? '';

        finalResults.add(
          SearchResultItem(
            id: userId,
            title: userName,
            subtitle: 'Edad: $userAge',
            avatarUrl: photoUrl,
            isUser: true,
          ),
        );
      }

      // -------------------------------------------
      // 2) Buscar PLAN por ID exacto
      // -------------------------------------------
      // Si el texto coincide con el doc.id, lo cargamos directamente
      final planDocRef =
          FirebaseFirestore.instance.collection('plans').doc(query);
      final planDocSnap = await planDocRef.get();
      if (planDocSnap.exists) {
        final planResult = await _buildSearchItemFromPlan(planDocSnap);
        if (planResult != null) {
          finalResults.add(planResult);
        }
      }

      // -------------------------------------------
      // 3) Buscar PLAN por "type" (nombre del plan) con coincidencia parcial
      // -------------------------------------------
      final plansQuery = await FirebaseFirestore.instance
          .collection('plans')
          .where('type', isGreaterThanOrEqualTo: query)
          .where('type', isLessThan: query + '\uf8ff')
          .get();

      for (var planDoc in plansQuery.docs) {
        final planResult = await _buildSearchItemFromPlan(planDoc);
        if (planResult != null) {
          finalResults.add(planResult);
        }
      }

      if (mounted) {
        setState(() {
          _results = finalResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al buscar: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Construye un [SearchResultItem] a partir del doc de un plan.
  /// Obtiene además la info del creador para mostrar su avatar.
  Future<SearchResultItem?> _buildSearchItemFromPlan(
      DocumentSnapshot planDoc) async {
    final data = planDoc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    // Aseguramos que tenga el 'id' en el Map antes de usar fromMap:
    final planMap = {
      'id': planDoc.id,
      ...data,
    };

    // Construimos el PlanModel con el factory fromMap
    PlanModel planModel;
    if (widget.fetchFullPlanById != null) {
      // Si alguien inyectó una función externa, la usamos:
      planModel = await widget.fetchFullPlanById!(planDoc.id);
    } else {
      // Caso contrario, parseamos nosotros:
      planModel = PlanModel.fromMap(planMap);
    }

    // Sobrescribimos (opcional) el avatar y el nombre del creador con datos frescos
    final creatorId = planModel.createdBy;
    if (creatorId.isNotEmpty) {
      try {
        final creatorSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .get();
        if (creatorSnap.exists && creatorSnap.data() != null) {
          final cData = creatorSnap.data()!;
          planModel.creatorName = cData['name'] ?? planModel.creatorName;
          planModel.creatorProfilePic =
              cData['photoUrl'] ?? planModel.creatorProfilePic;
        }
      } catch (_) {}
    }

    // Formatear la fecha para el subtitle
    String startDateString = '';
    if (planModel.startTimestamp != null) {
      final d = planModel.startTimestamp!;
      startDateString = '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    }

    return SearchResultItem(
      id: planModel.id,
      title: planModel.type, // nombre del plan
      subtitle: 'Inicia: $startDateString', // fecha
      avatarUrl: planModel.creatorProfilePic ?? '', // foto del creador
      isUser: false,
      planData: planModel,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si no queremos mostrar nada, retornamos un contenedor vacío
    if (!widget.isVisible || widget.query.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      // color claro para diferenciarlo
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400,
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      constraints: BoxConstraints(
        // caben ~6 items cómodamente
        maxHeight: widget.maxHeight,
      ),
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.black),
              ),
            )
          : _results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "No se han encontrado resultados.",
                    style: TextStyle(color: Colors.black87),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: (item.avatarUrl.isNotEmpty)
                            ? NetworkImage(item.avatarUrl)
                            : null,
                        backgroundColor: Colors.grey[300],
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(color: Colors.black),
                      ),
                      subtitle: Text(
                        item.isUser
                            ? item.subtitle // "Edad: X"
                            : item.subtitle, // "Inicia: dd/mm/yyyy"
                        style: const TextStyle(color: Colors.black54),
                      ),
                      onTap: () => _onTapSearchItem(item),
                    );
                  },
                ),
    );
  }

  /// Maneja el tap sobre un resultado.
  /// Si es usuario => va a [UserInfoCheck].
  /// Si es plan => va a [FrostedPlanDialog].
  void _onTapSearchItem(SearchResultItem item) {
    if (item.isUser) {
      // Ir a user_info_check.dart
      UserInfoCheck.open(context, item.id);
    } else {
      // Es un plan
      final plan = item.planData;
      if (plan == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FrostedPlanDialog(
            plan: plan,
            fetchParticipants: _fetchAllPlanParticipants,
          ),
        ),
      );
    }
  }

  /// Ejemplo de función para cargar participantes de un plan,
  /// usada por `FrostedPlanDialog`.
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
    PlanModel plan,
  ) async {
    final List<Map<String, dynamic>> res = [];
    final uds = plan.participants ?? [];
    for (final uid in uds) {
      final uDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (uDoc.exists) {
        final d = uDoc.data()!;
        res.add({
          'uid': uid,
          'name': d['name'] ?? 'Usuario',
          'age': d['age']?.toString() ?? '',
          'photoUrl': d['photoUrl'] ?? '',
          'isCreator': uid == plan.createdBy,
        });
      }
    }
    return res;
  }
}
