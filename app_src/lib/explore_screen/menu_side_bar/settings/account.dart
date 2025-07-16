// account.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../main/colors.dart' as MyColors;
import '../../../start/welcome_screen.dart';
import '../../../l10n/app_localizations.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.account),
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
                      'assets/icono-escribir.svg',
                      width: 24,
                      height: 24,
                    ),
                    title: Text(t.editProfile),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: SvgPicture.asset(
                      'assets/icono-candado.svg',
                      width: 24,
                      height: 24,
                    ),
                    title: Text(t.changeAccountPassword),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
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
                    title: Text(
                      t.deleteProfile,
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(t.deleteConfirmation),
                          content: Text(t.deleteQuestion),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(t.cancel),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _deleteAccount(context);
                              },
                              child: Text(t.accept),
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

Future<void> _deleteAccount(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final t = AppLocalizations.of(context);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final data = doc.data();

    if (data != null) {
      final urls = <String>[];
      void addUrl(dynamic u) {
        if (u is String && u.isNotEmpty) urls.add(u);
      }
      addUrl(data['photoUrl']);
      addUrl(data['coverPhotoUrl']);
      for (final key in ['coverPhotos', 'additionalPhotos']) {
        final list = data[key] as List<dynamic>?;
        if (list != null) {
          for (final u in list) addUrl(u);
        }
      }
      for (final url in urls) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }
    }

    await docRef.delete();

    // Tras borrar los datos en Firestore eliminamos la cuenta de autenticación
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop();
      if (e.code == 'requires-recent-login') {
        final success = await _showReauthDialog(context);
        if (success) {
          // Intentar de nuevo tras reautenticación
          await _deleteAccount(context);
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
      return;
    }

    if (context.mounted) {
      Navigator.of(context).pop(); // Cerrar el indicador de carga

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Text(t.deleteSuccess),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.accept),
            ),
          ],
        ),
      );

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (_) => false,
        );
      }
    }
  } on FirebaseAuthException catch (e) {
    Navigator.of(context).pop();
    if (e.code == 'requires-recent-login') {
      final success = await _showReauthDialog(context);
      if (success) {
        // Intentar de nuevo
        await _deleteAccount(context);
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

Future<bool> _showReauthDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ReauthDialog(),
  );
  return result == true;
}

class _ReauthDialog extends StatefulWidget {
  const _ReauthDialog();

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.reauthRequired),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.reauthExplanation),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(labelText: t.emailOrPhone),
            ),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: t.password),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.cancel),
        ),
        TextButton(
          onPressed: () async {
            final email = _emailCtrl.text.trim();
            final pwd = _passCtrl.text;
            if (email.isEmpty || pwd.isEmpty) return;
            try {
              final cred =
                  EmailAuthProvider.credential(email: email, password: pwd);
              await FirebaseAuth.instance.currentUser
                  ?.reauthenticateWithCredential(cred);
              if (mounted) Navigator.of(context).pop(true);
            } on FirebaseAuthException {
              if (!mounted) return;
              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  content: Text(t.reauthFailed),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.accept),
                    ),
                  ],
                ),
              );
            }
          },
          child: Text(t.continueDelete),
        ),
      ],
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _ageController = TextEditingController();
  Timer? _usernameDebounce;
  bool? _isUsernameAvailable;
  bool _isCheckingUsername = false;
  List<String> _usernameSuggestions = [];
  String _originalUsername = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _load();
  }

  void _onUsernameChanged() {
    final text = _usernameController.text.trim();
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(text);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameSuggestions = [];
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('user_name', isEqualTo: username)
        .get();

    bool available = snap.docs.isEmpty;
    if (!available && snap.docs.length == 1 && snap.docs.first.id == user?.uid) {
      available = true;
    }

    List<String> suggestions = [];
    if (!available) {
      for (int i = 0; i < 3; i++) {
        suggestions.add('$username${Random().nextInt(1000)}');
      }
    }

    if (mounted) {
      setState(() {
        _isUsernameAvailable = available;
        _usernameSuggestions = suggestions;
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _usernameController.text = data['user_name'] ?? '';
        _originalUsername = _usernameController.text;
        _ageController.text = (data['age'] ?? '').toString();
        await _checkUsernameAvailability(_usernameController.text.trim());
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    if (name.isEmpty || username.isEmpty || age == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.invalidFields)));
      return;
    }

    if (_isCheckingUsername || _isUsernameAvailable == false) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.usernameUnavailable)));
      _usernameController.text = _originalUsername;
      _usernameController.selection =
          TextSelection.collapsed(offset: _originalUsername.length);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': name,
        'nameLowercase': name.toLowerCase(),
        'user_name': username,
        'user_name_lowercase': username.toLowerCase(),
        'age': age,
      });
      if (mounted) {
        _originalUsername = username;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.profileUpdated)));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.editProfile)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: t.name),
            ),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: t.username,
                suffixIcon: _isCheckingUsername
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _isUsernameAvailable == null
                        ? null
                        : Icon(
                            _isUsernameAvailable! ? Icons.check : Icons.close,
                            color:
                                _isUsernameAvailable! ? Colors.green : Colors.red,
                          ),
              ),
            ),
            if (_usernameSuggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: _usernameSuggestions.map((s) {
                    return InkWell(
                      onTap: () {
                        _usernameController.text = s;
                        _usernameController.selection =
                            TextSelection.collapsed(offset: s.length);
                        _checkUsernameAvailability(s);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: MyColors.AppColors.lightLilac,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: MyColors.AppColors.greyBorder),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.age),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(t.save),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameDebounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;

  Future<void> _change() async {
    final t = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) return;

    final current = _currentController.text.trim();
    final newPwd = _newController.text;
    final confirm = _confirmController.text;
    if (current.isEmpty || newPwd.isEmpty || newPwd != confirm) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.checkFields)));
      return;
    }

    setState(() => _saving = true);
    try {
      final cred =
          EmailAuthProvider.credential(email: email, password: current);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPwd);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.passwordUpdated)));
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.changePassword)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _currentController,
              obscureText: true,
              decoration: InputDecoration(labelText: t.currentPassword),
            ),
            TextField(
              controller: _newController,
              obscureText: true,
              decoration: InputDecoration(labelText: t.newPassword),
            ),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(labelText: t.confirmPassword),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _change,
                child: Text(t.update),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}

