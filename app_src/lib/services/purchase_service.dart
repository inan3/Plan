import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/plan_model.dart';

class PurchaseService {
  PurchaseService._internal();
  static final PurchaseService instance = PurchaseService._internal();

  Future<void> startPlanPurchase(BuildContext context, PlanModel plan) async {
    // Aquí se integraría la lógica real de compras in‑app.
    // Por simplicidad mostramos un mensaje placeholder.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Se iniciaría la compra in-app')),
    );
  }
}
