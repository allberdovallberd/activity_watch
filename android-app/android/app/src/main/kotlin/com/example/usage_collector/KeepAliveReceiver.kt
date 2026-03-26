package com.example.usage_collector

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class KeepAliveReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        UsageCollectorService.startService(context)
        UsageCollectorService.scheduleKeepAlive(context, 2 * 60 * 1000L)
        WatchdogJobService.schedule(context)
        ServiceWatchdogWorker.schedule(context)
    }
}
