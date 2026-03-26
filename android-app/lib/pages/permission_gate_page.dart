import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class PermissionGatePage extends StatelessWidget {
  const PermissionGatePage({
    super.key,
    required this.status,
    required this.usageGranted,
    required this.batteryGranted,
    required this.exactAlarmGranted,
    required this.deviceAdminGranted,
    required this.onOpenUsageAccess,
    required this.onOpenBatteryOptimization,
    required this.onOpenExactAlarm,
    required this.onOpenDeviceAdmin,
  });

  final String status;
  final bool usageGranted;
  final bool batteryGranted;
  final bool exactAlarmGranted;
  final bool deviceAdminGranted;
  final Future<void> Function() onOpenUsageAccess;
  final Future<void> Function() onOpenBatteryOptimization;
  final Future<void> Function() onOpenExactAlarm;
  final Future<void> Function() onOpenDeviceAdmin;

  Widget _permissionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context);
    final statusColor = granted ? Colors.green : Colors.red;
    final statusText = granted ? l10n.granted : l10n.requiredText;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.12),
              child: Icon(icon, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: onTap,
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.permissionsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.requiredPermissions,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(l10n.permissionsIntro),
          const SizedBox(height: 12),
          _permissionTile(
            context: context,
            icon: Icons.insights,
            title: l10n.usageAccess,
            description: l10n.usageAccessDesc,
            granted: usageGranted,
            actionLabel: l10n.grant,
            onTap: () {
              onOpenUsageAccess();
            },
          ),
          const SizedBox(height: 12),
          Text(
            l10n.requiredPermissions,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _permissionTile(
            context: context,
            icon: Icons.battery_saver,
            title: l10n.batteryOptimization,
            description: l10n.batteryOptimizationDesc,
            granted: batteryGranted,
            actionLabel: l10n.allow,
            onTap: () {
              onOpenBatteryOptimization();
            },
          ),
          _permissionTile(
            context: context,
            icon: Icons.alarm,
            title: l10n.exactAlarm,
            description: l10n.exactAlarmDesc,
            granted: exactAlarmGranted,
            actionLabel: l10n.allow,
            onTap: () {
              onOpenExactAlarm();
            },
          ),
          _permissionTile(
            context: context,
            icon: Icons.admin_panel_settings,
            title: l10n.deviceAdmin,
            description: l10n.deviceAdminDesc,
            granted: deviceAdminGranted,
            actionLabel: l10n.enable,
            onTap: () {
              onOpenDeviceAdmin();
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.statusLabel}: $status',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
