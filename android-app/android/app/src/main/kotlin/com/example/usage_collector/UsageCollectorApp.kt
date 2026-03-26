package com.example.usage_collector

import android.app.Application

class UsageCollectorApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Thread {
            DeviceOwnerManager.applyPolicies(this)
        }.start()
        UsageCollectorService.startService(this)
        UsageCollectorService.scheduleKeepAlive(this, 2_000L)
        WatchdogJobService.schedule(this)
        ServiceWatchdogWorker.schedule(this)
    }
}
