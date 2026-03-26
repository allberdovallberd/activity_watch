import "package:flutter/material.dart";

import "../l10n/app_localizations.dart";
import "../src/settings_store.dart";
import "../src/sync_service.dart";

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _displayNameController = TextEditingController();
  final _backendUrlController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _deviceId = '';
  String _status = '';
  bool _editingDisplayName = false;
  bool _hasSettingsPassword = false;
  bool _showPasswordFields = false;
  bool _hidePasswords = true;
  _PasswordMode _passwordMode = _PasswordMode.none;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _backendUrlController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsStore.instance.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceId = settings.deviceId;
      _displayNameController.text = settings.displayName;
      _backendUrlController.text = settings.backendBaseUrl;
      _hasSettingsPassword = settings.hasSettingsPassword;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    await SettingsStore.instance.save(
      deviceId: _deviceId,
      displayName: _displayNameController.text.trim(),
      backendBaseUrl: _backendUrlController.text.trim(),
    );
    setState(() {
      _status = l10n.saved;
      _editingDisplayName = false;
    });
  }

  Future<void> _resetConfig() async {
    final l10n = AppLocalizations.of(context);
    final unlinkMsg = await SyncService().unlinkDevice();
    await SettingsStore.instance.clearConfig();
    await _loadSettings();
    setState(() {
      _status = l10n('configurationReset', {'message': unlinkMsg});
    });
  }

  void _startPasswordMode(_PasswordMode mode) {
    setState(() {
      _passwordMode = mode;
      _showPasswordFields = true;
      _hidePasswords = true;
      _status = '';
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  void _cancelPasswordMode() {
    setState(() {
      _passwordMode = _PasswordMode.none;
      _showPasswordFields = false;
      _hidePasswords = true;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _submitPasswordMode() async {
    final l10n = AppLocalizations.of(context);
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (_passwordMode == _PasswordMode.set) {
      if (next.isEmpty || confirm.isEmpty) {
        setState(() {
          _status = l10n.enterAndConfirmPassword;
        });
        return;
      }
      if (next != confirm) {
        setState(() {
          _status = l10n.passwordsDoNotMatch;
        });
        return;
      }
      await SettingsStore.instance.setSettingsPassword(next);
      setState(() {
        _hasSettingsPassword = true;
        _status = l10n.passwordSet;
      });
      _cancelPasswordMode();
      return;
    }

    if (current.isEmpty) {
      setState(() {
        _status = l10n.enterCurrentPassword;
      });
      return;
    }
    final valid = await SettingsStore.instance.verifySettingsPassword(current);
    if (!valid) {
      setState(() {
        _status = l10n.currentPasswordWrong;
      });
      return;
    }

    if (_passwordMode == _PasswordMode.change) {
      if (next.isEmpty || confirm.isEmpty) {
        setState(() {
          _status = l10n.enterNewAndConfirm;
        });
        return;
      }
      if (next != confirm) {
        setState(() {
          _status = l10n.passwordsDoNotMatch;
        });
        return;
      }
      await SettingsStore.instance.setSettingsPassword(next);
      setState(() {
        _status = l10n.passwordChanged;
      });
      _cancelPasswordMode();
      return;
    }

    if (_passwordMode == _PasswordMode.remove) {
      await SettingsStore.instance.clearSettingsPassword();
      setState(() {
        _hasSettingsPassword = false;
        _status = l10n.passwordRemoved;
      });
      _cancelPasswordMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
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
                    '${l10n.deviceIdLabel}: ${_deviceId.isEmpty ? '-' : _deviceId}',
                  ),
                  const SizedBox(height: 10),
                  if (_editingDisplayName)
                    TextField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        labelText: l10n.displayNameLabel,
                      ),
                    )
                  else
                    Text(
                      '${l10n.displayNameLabel}: ${_displayNameController.text.isEmpty ? '-' : _displayNameController.text}',
                    ),
                  const SizedBox(height: 10),
                  if (_editingDisplayName)
                    TextField(
                      controller: _backendUrlController,
                      decoration: InputDecoration(
                        labelText: l10n.backendUrlLabel,
                      ),
                    )
                  else
                    Text(
                      '${l10n.backendUrlLabel}: ${_backendUrlController.text.isEmpty ? '-' : _backendUrlController.text}',
                    ),
                  const SizedBox(height: 10),
                  if (!_editingDisplayName)
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _editingDisplayName = true;
                          _status = '';
                        });
                      },
                      child: Text(l10n.edit),
                    ),
                  if (_editingDisplayName)
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l10n.save),
                    ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsPassword,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (!_hasSettingsPassword && !_showPasswordFields)
                    FilledButton(
                      onPressed: () => _startPasswordMode(_PasswordMode.set),
                      child: Text(l10n.setPassword),
                    ),
                  if (_hasSettingsPassword && !_showPasswordFields) ...[
                    FilledButton(
                      onPressed: () => _startPasswordMode(_PasswordMode.change),
                      child: Text(l10n.changePassword),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => _startPasswordMode(_PasswordMode.remove),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l10n.removePassword),
                    ),
                  ],
                  if (_showPasswordFields) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _hidePasswords = !_hidePasswords;
                          });
                        },
                        icon: Icon(
                          _hidePasswords ? Icons.visibility : Icons.visibility_off,
                        ),
                        label: Text(_hidePasswords ? l10n.unhide : l10n.hide),
                      ),
                    ),
                    if (_passwordMode == _PasswordMode.change ||
                        _passwordMode == _PasswordMode.remove)
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: _hidePasswords,
                        decoration: InputDecoration(
                          labelText: l10n.currentPassword,
                        ),
                      ),
                    if (_passwordMode == _PasswordMode.set ||
                        _passwordMode == _PasswordMode.change) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _hidePasswords,
                        decoration: InputDecoration(
                          labelText: l10n.newPassword,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _hidePasswords,
                        decoration: InputDecoration(
                          labelText: l10n.confirmPassword,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _cancelPasswordMode,
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _submitPasswordMode,
                          style: FilledButton.styleFrom(
                            backgroundColor: _passwordMode == _PasswordMode.remove
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            switch (_passwordMode) {
                              _PasswordMode.set => l10n.set,
                              _PasswordMode.change => l10n.save,
                              _PasswordMode.remove => l10n.remove,
                              _PasswordMode.none => l10n.save,
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dangerZone,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.dangerZoneDesc),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _resetConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.resetConfig),
                  ),
                ],
              ),
            ),
          ),
          if (_status.isNotEmpty)
            Text('${l10n.statusPrefix}: $_status'),
        ],
      ),
    );
  }
}

enum _PasswordMode { none, set, change, remove }
