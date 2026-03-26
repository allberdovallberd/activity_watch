package com.example.usage_collector

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class AppDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        DeviceOwnerManager.applyPolicies(context)
        UsageCollectorService.startService(context)
        UsageCollectorService.scheduleKeepAlive(context, 2_000L)
        WatchdogJobService.schedule(context)
    }
}
