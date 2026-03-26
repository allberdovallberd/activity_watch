package com.example.usage_collector

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        when (action) {
    Intent.ACTION_BOOT_COMPLETED,
    Intent.ACTION_USER_UNLOCKED,
    Intent.ACTION_MY_PACKAGE_REPLACED,
    UsageCollectorService.ACTION_RESTART_SERVICE -> {

        DeviceOwnerManager.applyPolicies(context)
        UsageCollectorService.startService(context)

        // Schedule the restart
        UsageCollectorService.scheduleRestart(context, 3_000L)

        // Schedule keep-alive
        UsageCollectorService.scheduleKeepAlive(context, 5_000L)

        // Schedule watchdogs
        WatchdogJobService.schedule(context)
        ServiceWatchdogWorker.schedule(context)
    }
}
    }
}
