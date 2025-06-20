import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase_options.dart';

class UpdateService {
  UpdateService._();

  static Future<bool> mustUpdate() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: Duration.zero,              // cámbialo a unas horas en prod
    ));
    await rc.fetchAndActivate();

    final minRequired = rc.getInt('min_version_code');
    final info = await PackageInfo.fromPlatform();
    final current = int.tryParse(info.buildNumber) ?? 0;
    debugPrint("min_version_code = $minRequired");
    debugPrint("buildNumber = $current");
    return current < minRequired;
  }
}

class ForceUpdateGuard extends StatelessWidget {
  const ForceUpdateGuard({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UpdateService.mustUpdate(),
      builder: (context, snap) {
        final mustUpdate = snap.connectionState == ConnectionState.done && snap.data == true;
        if (mustUpdate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog<void>(
              context: navigatorKey.currentContext!,
              barrierDismissible: false,
              builder: (_) => WillPopScope(
                onWillPop: () async {
                  SystemNavigator.pop();
                  return false;
                },
                child: AlertDialog(
                  title: const Text('Actualización necesaria'),
                  content: const Text('Debes actualizar para continuar.'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        const pkg = 'com.company.plan';
                        launchUrl(
                          Uri.parse('https://play.google.com/store/apps/details?id=$pkg'),
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
