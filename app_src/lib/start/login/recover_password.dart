// recover_password.dart
import 'dart:convert';                           //  ⬅️  NUEVO
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../utils/auth_error_utils.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({Key? key}) : super(key: key);

  @override
  _RecoverPasswordScreenState createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController  = TextEditingController();
  final TextEditingController _pwdController   = TextEditingController();
  final TextEditingController _pwdConfirmController = TextEditingController();

  String? _verificationId;
  bool   _isEmail   = true;
  bool   _isLoading = false;

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /* ---------- ENVÍO DE CORREO (Cloud Function + nodemailer) ---------- */
  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) { _showSnack('Introduce tu correo'); return; }

    setState(() => _isLoading = true);
    final uri = Uri.parse(
      'https://europe-west1-plan-social-app.cloudfunctions.net/sendResetEmail'
    );
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},           //  ⬅️  JSON
        body: jsonEncode({'email': email}),
      );
      res.statusCode == 200
          ? _showSnack('Correo de recuperación enviado')
          : _showSnack('Error al enviar correo');
    } catch (_) {
      _showSnack('Error de red');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /* ------------------- ENVÍO DE SMS (Firebase Auth) --------------------- */
  Future<void> _sendSMS() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) { _showSnack('Introduce tu teléfono'); return; }

    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        AuthErrorUtils.showError(context, e);
        setState(() => _isLoading = false);
      },
      codeSent: (verId, _) {
        _verificationId = verId;
        setState(() => _isLoading = false);
        _showCodeDialog();
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /* ----------------- DIALOGO PARA INTRODUCIR CÓDIGO SMS ----------------- */
  void _showCodeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Introduce el código recibido por SMS',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Código SMS',
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _pwdController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
            ),
            TextField(
              controller: _pwdConfirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repite contraseña'),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Actualizar'),
            onPressed: () async {
              final code = _codeController.text.trim();
              final pwd  = _pwdController.text;
              final pwd2 = _pwdConfirmController.text;
              if (code.isEmpty || pwd.isEmpty || pwd2.isEmpty || pwd != pwd2) {
                _showSnack('Campos incompletos o no coinciden');
                return;
              }
              final cred = PhoneAuthProvider.credential(
                verificationId: _verificationId!,
                smsCode: code,
              );
              try {
                final userCred = await _auth.signInWithCredential(cred);
                await userCred.user!.updatePassword(pwd);
                await _auth.signOut();
                Navigator.of(context).pop();
                _showSnack('Contraseña actualizada');
                Navigator.of(context).pop();
              } on FirebaseAuthException catch (e) {
                AuthErrorUtils.showError(context, e);
              }
            },
          ),
        ],
      ),
    );
  }

  /* --------------------------------- UI --------------------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ToggleButtons(
              isSelected: [_isEmail, !_isEmail],
              onPressed: (i) => setState(() => _isEmail = i == 0),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Correo'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Teléfono'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isEmail)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'Correo electrónico'),
              ),
            if (!_isEmail)
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Teléfono (+34...)'),
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _isEmail ? _sendEmail : _sendSMS,
                    child: Text(_isEmail ? 'Enviar correo' : 'Enviar SMS'),
                  ),
          ],
        ),
      ),
    );
  }
}
