import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({Key? key}) : super(key: key);

  @override
  _RecoverPasswordScreenState createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _pwdConfirmController = TextEditingController();

  String? _verificationId;
  bool _isEmail = true;
  bool _isLoading = false;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Introduce tu correo');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: 'https://plansocialapp.es/reset_password.html',
          handleCodeInApp: false,
        ),
      );
      _showSnack('Correo de recuperación enviado');
    } on FirebaseAuthException catch (e) {
      _showSnack('Error: ${e.message}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendSMS() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnack('Introduce tu teléfono');
      return;
    }
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        _showSnack('Error: ${e.message}');
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

  void _showCodeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Código + nueva contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Código SMS'),
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
            onPressed: () async {
              final code = _codeController.text.trim();
              final pwd = _pwdController.text;
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
                _showSnack('Error: ${e.message}');
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

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
