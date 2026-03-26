package com.example.usage_collector

import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService

class WatchdogJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        UsageCollectorService.startService(applicationContext)
        schedule(applicationContext)
        jobFinished(params, false)
        return false
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }

    companion object {
        private const val JOB_ID = 20991
        private const val PERIODIC_MS = 15 * 60 * 1000L

        fun schedule(context: Context) {
            val scheduler = context.getSystemService(Service.JOB_SCHEDULER_SERVICE) as JobScheduler
            val component = ComponentName(context, WatchdogJobService::class.java)
            val builder = JobInfo.Builder(JOB_ID, component)
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_NONE)
                .setPersisted(true)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setPeriodic(PERIODIC_MS, 5 * 60 * 1000L)
            } else {
                @Suppress("DEPRECATION")
                builder.setPeriodic(PERIODIC_MS)
            }

            scheduler.schedule(builder.build())
        }
    }
}
