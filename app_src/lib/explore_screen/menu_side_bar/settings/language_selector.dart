import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../services/locale_provider.dart';

class LanguageSelectorScreen extends StatefulWidget {
  const LanguageSelectorScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSelectorScreen> createState() => _LanguageSelectorScreenState();
}

class _LanguageSelectorScreenState extends State<LanguageSelectorScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _languages = ['English', 'Español'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final query = _controller.text.toLowerCase();
    final filtered = _languages
        .where((l) => l.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    return Scaffold(
      appBar: AppBar(title: Text(t.languages)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: t.search,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final lang = filtered[index];
                return ListTile(
                  title: Text(lang),
                  onTap: () {
                    final code = lang.startsWith('English') ? 'en' : 'es';
                    context.read<LocaleProvider>().updateLocale(code);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
