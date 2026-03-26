package com.example.usage_collector

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class ServiceWatchdogWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result {
        UsageCollectorService.startService(applicationContext)
        UsageCollectorService.scheduleKeepAlive(applicationContext, 2_000L)
        return Result.success()
    }

    companion object {
        private const val UNIQUE_NAME = "usage_service_watchdog"

        fun schedule(context: Context) {
            val request =
                PeriodicWorkRequestBuilder<ServiceWatchdogWorker>(15, TimeUnit.MINUTES)
                    .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }
    }
}
