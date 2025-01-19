import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'plan_dialog_header.dart';
import 'plan_type_selector.dart';
import 'plan_details_form.dart';
import 'plan_map_picker.dart';
import 'plan_submit_buttons.dart';
import 'firebase_helpers.dart';

class NewPlanCreationScreen {
  static void showNewPlanDialog(BuildContext context) {
    final TextEditingController themeController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController addressController = TextEditingController();

    String? selectedPlanType;
    int? minAge, maxAge, maxParticipants;
    String? genderRestriction;
    LatLng? selectedLocation;
    String? selectedAddress;

    final List<String> genderOptions = ['Masculino', 'Femenino', 'Todos'];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Nuevo Plan',
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20), // Bordes redondeados del diálogo
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue, Colors.red],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PlanDialogHeader(),
                              const SizedBox(height: 20),
                              PlanTypeSelector(
                                onSelected: (value) => selectedPlanType = value,
                              ),
                              const SizedBox(height: 10),
                              PlanDetailsForm(
                                themeController: themeController,
                                descriptionController: descriptionController,
                                genderOptions: genderOptions,
                                onGenderSelected: (value) => genderRestriction = value,
                                onMinAgeChanged: (value) => minAge = value,
                                onMaxAgeChanged: (value) => maxAge = value,
                              ),
                              const SizedBox(height: 10),
                              PlanMapPicker(
                                addressController: addressController,
                                onAddressSelected: (String address) {
                                  selectedAddress = address;
                                },
                                onLocationSelected: (LatLng location) {
                                  selectedLocation = location;
                                },
                              ),
                              const SizedBox(height: 20),
                              PlanSubmitButtons(
                                onCancel: () => Navigator.of(context).pop(),
                                onCreate: () {
                                  if (selectedPlanType == null ||
                                      themeController.text.isEmpty ||
                                      descriptionController.text.isEmpty ||
                                      selectedLocation == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Por favor, completa todos los campos.'),
                                      ),
                                    );
                                    return;
                                  }
                                  FirebaseHelpers.createNewPlan(
                                    context,
                                    type: selectedPlanType!,
                                    theme: themeController.text.trim(),
                                    description: descriptionController.text.trim(),
                                    maxParticipants: maxParticipants,
                                    minAge: minAge,
                                    maxAge: maxAge,
                                    genderRestriction: genderRestriction ?? 'Todos',
                                    location: selectedLocation!,
                                    address: selectedAddress ?? '',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
