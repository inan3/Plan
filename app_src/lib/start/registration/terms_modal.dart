import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';

Future<bool?> showTermsModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _TermsModal(),
  );
}

class _TermsModal extends StatelessWidget {
  const _TermsModal();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(top: 50),
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Aceptar las condiciones y la política de privacidad',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              const _SummaryText(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('termsAccepted', true);
                    await prefs.setString('termsVersion', '2024-05');
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                  child: const Text('Acepto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryText extends StatelessWidget {
  const _SummaryText();

  @override
  Widget build(BuildContext context) {
    TextSpan link(String text, String url) => TextSpan(
          text: text,
          style: const TextStyle(color: Colors.blue),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication),
        );
    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        children: [
          const TextSpan(
              text:
                  'Al tocar Acepto, creas tu cuenta y aceptas las '),
          link('Condiciones', 'https://plansocial.app/legal/condiciones'),
          const TextSpan(
              text:
                  ' de la app. Obtén información sobre cómo recogemos, utilizamos y compartimos tus datos en nuestra '),
          link('Política de privacidad',
              'https://plansocial.app/legal/privacidad'),
          const TextSpan(
              text: ' y cómo usamos las cookies en nuestra '),
          link('Política de cookies', 'https://plansocial.app/legal/cookies'),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

