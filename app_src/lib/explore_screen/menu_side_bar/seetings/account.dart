// account.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuenta'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: SvgPicture.asset(
                      'assets/icono-email.svg',
                      width: 24,
                      height: 24,
                    ),
                    title: const Text('Dirección de correo electrónico'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmailScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: SvgPicture.asset(
                      'assets/icono-telefono.svg',
                      width: 24,
                      height: 24,
                    ),
                    title: const Text('Número de teléfono'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PhoneScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: SvgPicture.asset(
                      'assets/icono-eliminar.svg',
                      width: 24,
                      height: 24,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Eliminar mi perfil',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmar eliminación'),
                          content: const Text('¿Estás seguro de que quieres eliminar tu perfil?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                // TODO: Acción de eliminar perfil
                              },
                              child: const Text('Aceptar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmailScreen extends StatelessWidget {
  const EmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: reemplazar con email real del usuario
    const registeredEmail = 'usuario@ejemplo.com';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Correo electrónico'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(registeredEmail),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Cambiar dirección de correo
                },
                child: const Text('Cambiar dirección de correo'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Cambiar contraseña
                },
                child: const Text('Cambiar contraseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhoneScreen extends StatelessWidget {
  const PhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: reemplazar con teléfono real del usuario
    const registeredPhone = '+34 600 123 456';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teléfono'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(registeredPhone),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Cambiar número de teléfono
                },
                child: const Text('Cambiar número de teléfono'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
