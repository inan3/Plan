import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../main/colors.dart';
import 'user_registration_screen.dart';
import 'verification_provider.dart';

class PasswordSelectionScreen extends StatefulWidget {
  final User firebaseUser;
  const PasswordSelectionScreen({Key? key, required this.firebaseUser}) : super(key: key);

  @override
  State<PasswordSelectionScreen> createState() => _PasswordSelectionScreenState();
}

class _PasswordSelectionScreenState extends State<PasswordSelectionScreen> {
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _showPwd = false;
  bool _showConfirm = false;

  bool get _hasUppercase => _pwdController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _pwdController.text.contains(RegExp(r'[0-9]'));
  bool get _valid => _hasUppercase && _hasNumber;
  bool get _match => _pwdController.text == _confirmController.text;

  @override
  void initState() {
    super.initState();
    _pwdController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pwdController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _continue() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UserRegistrationScreen(
          provider: VerificationProvider.google,
          firebaseUser: widget.firebaseUser,
          password: _pwdController.text,
        ),
      ),
    );
  }

  Widget _buildRequirement({required bool ok, required String text}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightTurquoise,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyBorder),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check : Icons.close,
              color: ok ? AppColors.planColor : Colors.black),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.roboto(
                color: ok ? AppColors.planColor : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 150,
                child: Image.asset('assets/plan-sin-fondo.png'),
              ),
              const SizedBox(height: 24),
              Text(
                'Elige una contraseña',
                style: GoogleFonts.roboto(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pwdController,
                obscureText: !_showPwd,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(_showPwd
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(() => _showPwd = !_showPwd),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildRequirement(
                ok: _hasUppercase,
                text: 'Al menos una letra mayúscula',
              ),
              _buildRequirement(
                ok: _hasNumber,
                text: 'Al menos un número',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _confirmController,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _valid && _match ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.planColor,
                  ),
                  child: const Text(
                    'Seguir',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
