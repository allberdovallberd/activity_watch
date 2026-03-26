import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/language_dialog.dart';
import '../src/settings_store.dart';
import '../src/sync_service.dart';
import 'settings_page.dart';

class CollectorHomePage extends StatefulWidget {
  const CollectorHomePage({super.key});

  @override
  State<CollectorHomePage> createState() => _CollectorHomePageState();
}

class _CollectorHomePageState extends State<CollectorHomePage>
    with WidgetsBindingObserver {
  final SyncService _syncService = SyncService();
  String _deviceId = '';
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSettings();
    }
  }

  bool get _isDeviceSet => _deviceId.trim().isNotEmpty;

  Future<void> _loadSettings() async {
    final settings = await SettingsStore.instance.load();
    if (!mounted) {
      return;
    }
    if (_deviceId == settings.deviceId && _displayName == settings.displayName) {
      return;
    }
    setState(() {
      _deviceId = settings.deviceId;
      _displayName = settings.displayName;
    });
  }

  Future<void> _openSettings() async {
    final hasPassword = await SettingsStore.instance.hasSettingsPassword();
    if (!mounted) {
      return;
    }
    if (hasPassword) {
      final allowed = await _promptForSettingsPassword();
      if (!mounted || !allowed) {
        return;
      }
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
    await _loadSettings();
  }

  Future<bool> _promptForSettingsPassword() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    var error = '';
    var hidden = true;
    var loading = false;
    var allowed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> submit() async {
              final value = controller.text;
              if (value.isEmpty) {
                setStateDialog(() {
                  error = l10n.enterPassword;
                });
                return;
              }
              setStateDialog(() {
                loading = true;
                error = '';
              });
              final ok = await SettingsStore.instance.verifySettingsPassword(
                value,
              );
              if (!ctx.mounted) {
                return;
              }
              if (ok) {
                allowed = true;
                Navigator.of(ctx).pop();
                return;
              }
              setStateDialog(() {
                loading = false;
                error = l10n.wrongPassword;
              });
            }

            return AlertDialog(
              title: Text(l10n.settingsPassword),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    obscureText: hidden,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setStateDialog(() {
                            hidden = !hidden;
                          });
                        },
                        icon: Icon(
                          hidden ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!loading) {
                        submit();
                      }
                    },
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(ctx).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: loading ? null : submit,
                  child: Text(loading ? l10n.checking : l10n.enter),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return allowed;
  }

  Future<void> _showSetNowDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    String error = '';
    bool loading = false;
    bool success = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> submit() async {
              final value = controller.text.trim().toUpperCase();
              if (value.isEmpty) {
                setStateDialog(() {
                  error = l10n.deviceIdEmpty;
                });
                return;
              }
              setStateDialog(() {
                error = '';
                loading = true;
              });
              final result = await _syncService.linkDevice(
                deviceId: value,
                displayName: _displayName,
              );
              if (!mounted) {
                return;
              }
              if (result.status == LinkStatus.success) {
                setStateDialog(() {
                  loading = false;
                  success = true;
                });
                await _loadSettings();
                await Future.delayed(const Duration(milliseconds: 900));
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                }
              } else {
                setStateDialog(() {
                  loading = false;
                  error = result.message;
                });
              }
            }

            return AlertDialog(
              title: Text(l10n.setDeviceId),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!success)
                    TextField(
                      controller: controller,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.deviceIdLabel,
                      ),
                    ),
                  if (success)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 30,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.allSetDialog,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                if (!loading && !success)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.cancel),
                  ),
                if (!success)
                  FilledButton(
                    onPressed: loading ? null : submit,
                    child: Text(loading ? l10n.checking : l10n.set),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(
            onPressed: () => showLanguageDialog(context),
            icon: const Icon(Icons.language),
            tooltip: l10n.openLanguageDialogTooltip,
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: l10n.openSettingsTooltip,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.deviceStatus,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (!_isDeviceSet) ...[
                    Text(
                      l10n.deviceNotSet,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _showSetNowDialog,
                      child: Text(l10n.setNow),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          l10n.allSet,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('${l10n.deviceIdLabel}: $_deviceId'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
