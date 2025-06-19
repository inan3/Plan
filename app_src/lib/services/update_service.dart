import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase_options.dart';

class UpdateService {
  UpdateService._();

  static const int _buildNumber =
      int.fromEnvironment('FLUTTER_BUILD_NUMBER', defaultValue: 0);

  static Future<bool> mustUpdate() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 12),
      ));
      await rc.fetchAndActivate();
      final minVersion = rc.getInt('min_version_code');
      return _buildNumber < minVersion;
    } catch (_) {
      return false;
    }
  }
}

class ForceUpdateGuard extends StatelessWidget {
  const ForceUpdateGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UpdateService.mustUpdate(),
      builder: (context, snapshot) {
        final showDialogFlag = snapshot.connectionState == ConnectionState.done &&
            snapshot.data == true;
        if (showDialogFlag) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (context) => WillPopScope(
                onWillPop: () async {
                  SystemNavigator.pop();
                  return false;
                },
                child: AlertDialog(
                  title: const Text('Actualización necesaria'),
                  content: const Text('Debes actualizar para continuar.'),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        const packageName = 'com.company.plan';
                        final uri = Uri.parse(
                          'https://play.google.com/store/apps/details?id=$packageName',
                        );
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: const Text('Actualizar'),
                    ),
                  ],
                ),
              ),
            );
          });
        }
        return child;
      },
    );
  }
}
