import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/locale.state.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return PopupMenuButton<Locale>(
      initialValue: localeProvider.locale,
      onSelected: (locale) => localeProvider.setLocale(locale),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: const Locale('en'),
          child: Row(
            children: [
              if (localeProvider.locale.languageCode == 'en')
                const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
              const Text('English'),
            ],
          ),
        ),
        PopupMenuItem(
          value: const Locale('zh'),
          child: Row(
            children: [
              if (localeProvider.locale.languageCode == 'zh')
                const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
              const Text('中文'),
            ],
          ),
        ),
      ],
      child: const Icon(Icons.language),
    );
  }
}