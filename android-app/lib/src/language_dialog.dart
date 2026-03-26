import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import 'app_locale_controller.dart';

Future<void> showLanguageDialog(BuildContext context) async {
  final controller = context.read<AppLocaleController>();
  final l10n = AppLocalizations.of(context);
  final current = controller.languageCode;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageTile(
              title: l10n.turkmen,
              selected: current == 'tr',
              onTap: () async {
                await controller.setLanguageCode('tr');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
            _LanguageTile(
              title: l10n.english,
              selected: current == 'en',
              onTap: () async {
                await controller.setLanguageCode('en');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
            _LanguageTile(
              title: l10n.russian,
              selected: current == 'ru',
              onTap: () async {
                await controller.setLanguageCode('ru');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(title),
      onTap: () {
        onTap();
      },
    );
  }
}
