//general_notifications.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_service.dart';

class GeneralNotificationsScreen extends StatefulWidget {
  const GeneralNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<GeneralNotificationsScreen> createState() => _GeneralNotificationsScreenState();
}

class _GeneralNotificationsScreenState extends State<GeneralNotificationsScreen> {
  bool _enabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('notificationsEnabled') ?? true;
    await NotificationService.instance.init(enabled: _enabled);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', v);
    setState(() => _enabled = v);

    if (v) {
      await NotificationService.instance.enable();
    } else {
      await NotificationService.instance.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.notifications),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      backgroundColor: Colors.grey.shade200,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.notificationsDesc,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(t.enableNotifications, style: const TextStyle(fontSize: 16)),
                    ),
                    Text(_enabled ? t.enabled : t.disabled,
                        style: const TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _enabled,
                      onChanged: _toggle,
                      activeTrackColor: Colors.green,
                      activeColor: Colors.white,
                      inactiveTrackColor: Colors.grey,
                      inactiveThumbColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Espacio reservado para notificaciones de chat
            Text(
              t.chatPending,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }}