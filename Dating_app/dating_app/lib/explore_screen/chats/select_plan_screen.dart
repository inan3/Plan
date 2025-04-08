import 'package:flutter/material.dart';
import 'my_plans_selection.dart';
import 'subscribed_plans_selection.dart';

class SelectPlanScreen extends StatefulWidget {
  const SelectPlanScreen({Key? key}) : super(key: key);

  @override
  _SelectPlanScreenState createState() => _SelectPlanScreenState();
}

class _SelectPlanScreenState extends State<SelectPlanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Aquí guardamos las IDs de planes seleccionados
  final Set<String> _selectedPlanIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _toggleSelection(String planId) {
    setState(() {
      if (_selectedPlanIds.contains(planId)) {
        _selectedPlanIds.remove(planId);
      } else {
        _selectedPlanIds.add(planId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Planes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mis Planes'),
            Tab(text: 'Suscritos'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // Devolvemos la selección al Pop
              Navigator.pop(context, _selectedPlanIds);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña 1: Mis planes
          MyPlansSelection(
            selectedIds: _selectedPlanIds,
            onToggleSelected: _toggleSelection,
          ),
          // Pestaña 2: Planes suscritos
          SubscribedPlansSelection(
            selectedIds: _selectedPlanIds,
            onToggleSelected: _toggleSelection,
          ),
        ],
      ),
    );
  }
}
