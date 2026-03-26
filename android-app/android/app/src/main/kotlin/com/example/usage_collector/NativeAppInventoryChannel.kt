package com.example.usage_collector

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.ConnectivityManager
import android.net.Uri
import android.net.TrafficStats
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.Executors

object NativeAppInventoryChannel {
    private const val CHANNEL_NAME = "usage_collector/native"
    private const val ACTION_DEVICE_ADMIN_SETTINGS = "android.settings.DEVICE_ADMIN_SETTINGS"
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call: MethodCall, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    runAsync(result, "APP_LIST_FAILED") {
                        getInstalledApps(context)
                    }
                }
                "getSelfPackage" -> {
                    try {
                        result.success(context.packageName)
                    } catch (e: Exception) {
                        result.error("SELF_PACKAGE_FAILED", e.message, null)
                    }
                }
                "isIgnoringBatteryOptimizations" -> {
                    try {
                        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(context.packageName))
                    } catch (e: Exception) {
                        result.error("BATTERY_CHECK_FAILED", e.message, null)
                    }
                }
                "canScheduleExactAlarms" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            result.success(alarmManager.canScheduleExactAlarms())
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("EXACT_ALARM_CHECK_FAILED", e.message, null)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_SETTINGS_FAILED", e.message, null)
                    }
                }
                "openExactAlarmSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:${context.packageName}")
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:${context.packageName}")
                            }
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("EXACT_ALARM_SETTINGS_FAILED", e.message, null)
                    }
                }
                "openUsageAccessSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("USAGE_ACCESS_SETTINGS_FAILED", e.message, null)
                    }
                }
                "getDeviceToken" -> {
                    try {
                        result.success(getStableDeviceToken(context))
                    } catch (e: Exception) {
                        result.error("DEVICE_TOKEN_FAILED", e.message, null)
                    }
                }
                "isDeviceAdminActive" -> {
                    try {
                        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val admin = ComponentName(context, AppDeviceAdminReceiver::class.java)
                        result.success(dpm.isAdminActive(admin))
                    } catch (e: Exception) {
                        result.error("DEVICE_ADMIN_CHECK_FAILED", e.message, null)
                    }
                }
                "requestDeviceAdmin" -> {
                    try {
                        val admin = ComponentName(context, AppDeviceAdminReceiver::class.java)
                        val addAdminIntent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, admin)
                            putExtra(
                                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                AndroidStrings.deviceAdminExplanation(context),
                            )
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        val explicitAddAdminIntent = Intent().apply {
                            component = ComponentName(
                                "com.android.settings",
                                "com.android.settings.DeviceAdminAdd",
                            )
                            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, admin)
                            putExtra(
                                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                AndroidStrings.deviceAdminExplanation(context),
                            )
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        val adminSettingsIntent = Intent(ACTION_DEVICE_ADMIN_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        val securitySettingsIntent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        val openedAdmin =
                            tryStart(context, explicitAddAdminIntent) || tryStart(context, addAdminIntent)
                        if (openedAdmin) {
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        if (tryStart(context, adminSettingsIntent) || tryStart(context, securitySettingsIntent) || tryStart(context, fallback)) {
                            result.error(
                                "DEVICE_ADMIN_UNAVAILABLE",
                                "Direct Device Admin activation is unavailable on this device. Opened fallback settings.",
                                null,
                            )
                        } else {
                            result.error(
                                "DEVICE_ADMIN_REQUEST_FAILED",
                                "No settings intent available for Device Admin on this device.",
                                null,
                            )
                        }
                    } catch (e: Exception) {
                        result.error("DEVICE_ADMIN_REQUEST_FAILED", e.message, null)
                    }
                }
                "getTotalBytes" -> {
                    runAsync(result, "DATA_USAGE_FAILED") {
                        val rx = TrafficStats.getTotalRxBytes()
                        val tx = TrafficStats.getTotalTxBytes()
                        if (rx == TrafficStats.UNSUPPORTED.toLong() || tx == TrafficStats.UNSUPPORTED.toLong()) {
                            0
                        } else {
                            rx + tx
                        }
                    }
                }
                "getAppTrafficTotals" -> {
                    runAsync(result, "APP_DATA_USAGE_FAILED") {
                        getAppTrafficTotals(context)
                    }
                }
                "hasUsageAccess" -> {
                    runAsync(result, "USAGE_ACCESS_FAILED") {
                        hasUsageAccess(context)
                    }
                }
                "getUsageEventTotals" -> {
                    val startMs = call.argument<Number>("start_ms")?.toLong() ?: 0L
                    val endMs = call.argument<Number>("end_ms")?.toLong() ?: 0L
                    runAsync(result, "USAGE_EVENTS_FAILED") {
                        getUsageEventTotals(context, startMs, endMs)
                    }
                }
                "getAppsUsageForInterval" -> {
                    val startMs = call.argument<Number>("start_ms")?.toLong() ?: 0L
                    val endMs = call.argument<Number>("end_ms")?.toLong() ?: 0L
                    runAsync(result, "APPS_USAGE_FAILED") {
                        getAppsUsageForInterval(context, startMs, endMs)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun <T> runAsync(
        result: MethodChannel.Result,
        errorCode: String,
        work: () -> T,
    ) {
        ioExecutor.execute {
            try {
                val data = work()
                mainHandler.post { result.success(data) }
            } catch (e: Exception) {
                mainHandler.post { result.error(errorCode, e.message, null) }
            }
        }
    }

    private fun getInstalledApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        @Suppress("DEPRECATION")
        val apps: List<ApplicationInfo> = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        return apps.mapNotNull { appInfo ->
            val packageName = appInfo.packageName
            val appName = try {
                val label = pm.getApplicationLabel(appInfo)?.toString()?.trim().orEmpty()
                if (label.isEmpty()) packageName else label
            } catch (_: Exception) {
                packageName
            }
            val isTracking = packageName == context.packageName
            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
                (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0 ||
                isTracking
            val iconBase64 = try {
                val drawable = pm.getApplicationIcon(appInfo)
                drawableToBase64Png(drawable)
            } catch (_: Exception) {
                null
            }
            mapOf(
                "package_name" to packageName,
                "app_name" to appName,
                "icon_base64" to iconBase64,
                "is_system" to isSystem,
                "is_tracking" to isTracking,
            )
        }
    }

    private fun tryStart(context: Context, intent: Intent): Boolean {
        return try {
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun getStableDeviceToken(context: Context): String {
        // Best-effort stable ID. On device-owner devices, use enrollment ID if available.
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            if (dpm != null && dpm.isDeviceOwnerApp(context.packageName)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val enrollmentId = dpm.getEnrollmentSpecificId()
                    if (!enrollmentId.isNullOrBlank()) {
                        return enrollmentId
                    }
                }
            }
        } catch (_: Exception) {
            // ignore and fallback
        }

        try {
            val androidId = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ANDROID_ID,
            )
            if (!androidId.isNullOrBlank()) {
                return androidId
            }
        } catch (_: Exception) {
            // ignore and fallback
        }

        val prefs = context.getSharedPreferences("usage_collector_prefs", Context.MODE_PRIVATE)
        var fallback = prefs.getString("fallback_device_token", "") ?: ""
        if (fallback.isBlank()) {
            fallback = UUID.randomUUID().toString()
            prefs.edit().putString("fallback_device_token", fallback).apply()
        }
        return fallback
    }

    private fun drawableToBase64Png(drawable: Drawable): String? {
        val bitmap = Bitmap.createBitmap(48, 48, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        val ok = bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        if (!ok) {
            return null
        }
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }

    private fun getAppTrafficTotals(context: Context): List<Map<String, Any>> {
        val pm = context.packageManager
        @Suppress("DEPRECATION")
        val apps: List<ApplicationInfo> = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val rows = ArrayList<Map<String, Any>>(apps.size)
        for (appInfo in apps) {
            val uid = appInfo.uid
            val rx = TrafficStats.getUidRxBytes(uid)
            val tx = TrafficStats.getUidTxBytes(uid)
            if (rx == TrafficStats.UNSUPPORTED.toLong() || tx == TrafficStats.UNSUPPORTED.toLong()) {
                continue
            }
            val total = rx + tx
            if (total < 0) {
                continue
            }
            rows.add(
                mapOf(
                    "package_name" to appInfo.packageName,
                    "total_bytes" to total,
                ),
            )
        }
        return rows
    }

    private fun hasUsageAccess(context: Context): Boolean {
        try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    appOps.unsafeCheckOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        context.packageName,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        context.packageName,
                    )
                }
            if (mode == AppOpsManager.MODE_ALLOWED) {
                return true
            }
        } catch (_: Exception) {
            // ignore and fallback
        }

        return try {
            val usageManager =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = usageManager.queryAndAggregateUsageStats(
                now - 24 * 60 * 60 * 1000L,
                now,
            )
            stats.isNotEmpty()
        } catch (_: Exception) {
            false
        }
    }

    private fun getUsageEventTotals(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): List<Map<String, Any>> {
        if (endMs <= startMs) {
            return emptyList()
        }
        val totals = fetchScreenUsageForInterval(context, startMs, endMs)
        val rows = ArrayList<Map<String, Any>>(totals.size)
        totals.forEach { (pkg, totalMs) ->
            rows.add(
                mapOf(
                    "package_name" to pkg,
                    "total_ms" to totalMs,
                ),
            )
        }
        return rows
    }

    private fun getAppsUsageForInterval(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): List<Map<String, Any>> {
        if (endMs <= startMs) {
            return emptyList()
        }
        val screenUsage = fetchScreenUsageForInterval(context, startMs, endMs)

        val packageManager = context.packageManager
        @Suppress("DEPRECATION")
        val apps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)

        val rows = ArrayList<Map<String, Any>>(apps.size)
        for (appInfo in apps) {
            val packageName = appInfo.packageName
            if (packageName.isNullOrBlank()) {
                continue
            }
            val screenMs = screenUsage[packageName] ?: 0L
            if (screenMs <= 0L) {
                continue
            }
            rows.add(
                mapOf(
                    "package_name" to packageName,
                    "screen_time_ms" to screenMs,
                    "mobile_bytes" to 0L,
                    "wifi_bytes" to 0L,
                ),
            )
        }
        return rows
    }

    private fun fetchScreenUsageForInterval(
        context: Context,
        startMs: Long,
        endMs: Long,
    ): Map<String, Long> {
        val usageManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        data class ResumedEvent(val packageName: String, val timeStamp: Long)

        val usageMap = HashMap<String, Long>()
        val lastResumedEvents = HashMap<String, ResumedEvent>()
        val events = usageManager.queryEvents(startMs - (3 * 60 * 60 * 1000), endMs)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            val className = event.className ?: ""
            val eventKey = packageName + className
            val currentTimeStamp = event.timeStamp
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    lastResumedEvents[eventKey] = ResumedEvent(packageName, currentTimeStamp)
                }
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    lastResumedEvents.remove(eventKey)?.let { lastResumedEvent ->
                        if (currentTimeStamp > startMs) {
                            val resumeTime = maxOf(lastResumedEvent.timeStamp, startMs)
                            val delta = currentTimeStamp - resumeTime
                            if (delta > 0) {
                                usageMap[packageName] =
                                    (usageMap[packageName] ?: 0L) + delta
                            }
                        }
                    }
                }
            }
        }
        lastResumedEvents.values.maxByOrNull { it.timeStamp }?.let { entry ->
            val packageName = entry.packageName
            val resumeTime = maxOf(entry.timeStamp, startMs)
            val delta = endMs - resumeTime
            if (delta > 0) {
                usageMap[packageName] = (usageMap[packageName] ?: 0L) + delta
            }
        }
        // Merge aggregated stats for packages missing in events (older dates on some devices).
        val stats = usageManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startMs,
            endMs,
        )
        val intervalMs = endMs - startMs
        for (stat in stats) {
            val pkg = stat.packageName ?: continue
            val total = stat.totalTimeInForeground
            if (total <= 0L) {
                continue
            }
            val capped = if (intervalMs > 0) minOf(total, intervalMs) else total
            val existing = usageMap[pkg] ?: 0L
            if (capped > existing) {
                usageMap[pkg] = capped
            }
        }
        return usageMap.filterValues { it > 0L }
    }

    private fun fetchNetworkUsageForInterval(
        networkStatsManager: NetworkStatsManager,
        networkType: Int,
        startMs: Long,
        endMs: Long,
    ): Map<Int, Long> {
        val usageMap = HashMap<Int, Long>()
        try {
            val stats = networkStatsManager.querySummary(networkType, null, startMs, endMs)
            stats.use {
                val bucket = NetworkStats.Bucket()
                while (stats.hasNextBucket()) {
                    stats.getNextBucket(bucket)
                    val uid = bucket.uid
                    usageMap[uid] =
                        (usageMap[uid] ?: 0L) + bucket.rxBytes + bucket.txBytes
                }
            }
        } catch (_: Exception) {
            // ignore
        }
        return usageMap.filterValues { it > 0L }
    }
}
