import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Utilidades para mostrar mensajes de error de FirebaseAuth en español.
class AuthErrorUtils {
  AuthErrorUtils._();

  /// Muestra un [AlertDialog] con un mensaje traducido según [e.code].
  static void showError(BuildContext context, FirebaseAuthException e) {
    final String msg = _errorMessages[e.code] ??
        'Se produjo un error. Inténtalo de nuevo.';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Atención'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Mapa de códigos de error de FirebaseAuth a mensajes en español.
  static const Map<String, String> _errorMessages = {
    'invalid-phone-number': 'Número de teléfono no válido',
    'missing-phone-number': 'Introduce un número de teléfono',
    'invalid-verification-code': 'Código de verificación incorrecto',
    'invalid-verification-id': 'Identificador de verificación inválido',
    'missing-verification-code': 'Introduce el código de verificación',
    'missing-verification-id': 'Falta el identificador de verificación',
    'session-expired': 'La sesión ha expirado, solicita un nuevo código',
    'credential-already-in-use':
        'La credencial ya está en uso por otra cuenta',
    'user-disabled': 'El usuario está deshabilitado',
    'operation-not-allowed': 'Operación no permitida',
    'too-many-requests':
        'Hemos bloqueado las solicitudes por actividad inusual. Inténtalo más tarde',
    'network-request-failed': 'Error de red. Revisa tu conexión',
    'quota-exceeded': 'Cuota excedida. Inténtalo más tarde',
  };
}
