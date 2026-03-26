package com.example.usage_collector

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class UsageCollectorService : Service() {
    companion object {
        private const val CHANNEL_ID = "usage_collector_service_channel"
        private const val CHANNEL_NAME = "UlanyЕџ Service"
        private const val NOTIFICATION_ID = 2032
        private const val KEEP_ALIVE_REQ_CODE = 7001
        private const val RESTART_REQ_CODE = 7002
        private const val KEEP_ALIVE_INTERVAL_MS = 2 * 60 * 1000L
        private const val WATCHDOG_INTERVAL_MS = 20_000L
        private const val ENGINE_WARMUP_MS = 10_000L
        private const val STARTUP_TICK_DELAY_MS = 3_000L
        const val ACTION_RESTART_SERVICE = "com.example.usage_collector.ACTION_RESTART_SERVICE"
        const val ACTION_KEEP_ALIVE_TICK = "com.example.usage_collector.ACTION_KEEP_ALIVE_TICK"
        const val ACTION_APP_FOREGROUND = "com.example.usage_collector.ACTION_APP_FOREGROUND"
        const val ACTION_APP_BACKGROUND = "com.example.usage_collector.ACTION_APP_BACKGROUND"

        fun startService(context: Context) {
            val serviceIntent = Intent(context, UsageCollectorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }

        fun scheduleKeepAlive(context: Context, delayMs: Long = KEEP_ALIVE_INTERVAL_MS) {
            val tickIntent = Intent(context, KeepAliveReceiver::class.java).apply {
                action = ACTION_KEEP_ALIVE_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                KEEP_ALIVE_REQ_CODE,
                tickIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = SystemClock.elapsedRealtime() + delayMs
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                }
            } catch (_: SecurityException) {
                alarmManager.set(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            }
        }

        fun scheduleRestart(context: Context, delayMs: Long = 3_000L) {
    val restartIntent = Intent(context, UsageCollectorService::class.java).apply {
        action = ACTION_RESTART_SERVICE
    }
    val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        PendingIntent.getForegroundService(
            context,
            RESTART_REQ_CODE,
            restartIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    } else {
        PendingIntent.getService(
            context,
            RESTART_REQ_CODE,
            restartIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val triggerAt = SystemClock.elapsedRealtime() + delayMs
    try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        } else {
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        }
    } catch (_: SecurityException) {
        alarmManager.set(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            triggerAt,
            pendingIntent,
        )
    }
}

        fun setAppInForeground(context: Context, isForeground: Boolean) {
            val intent = Intent(context, UsageCollectorService::class.java).apply {
                action = if (isForeground) ACTION_APP_FOREGROUND else ACTION_APP_BACKGROUND
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private var flutterEngine: FlutterEngine? = null
    private var backgroundChannel: MethodChannel? = null
    private var dartStarted = false
    private var lastTickOkAt = 0L
    private var lastEngineStartAt = 0L
    private var wakeLock: PowerManager.WakeLock? = null
    private val watchdogHandler = Handler(Looper.getMainLooper())
    private var watchdogStarted = false
    private var startupScheduled = false
    private var delayedTickScheduled = false
    private val watchdogRunnable = object : Runnable {
        override fun run() {
            ensureDartRuntime()
            acquireWakeLock(120_000L)
            scheduleKeepAlive(applicationContext)
            sendTick()
            watchdogHandler.postDelayed(this, WATCHDOG_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        acquireWakeLock(30_000L)
        scheduleKeepAlive(applicationContext)
        WatchdogJobService.schedule(applicationContext)
        ServiceWatchdogWorker.schedule(applicationContext)
        ensureDartRuntime()
        scheduleStartupTick()
        startWatchdog()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_APP_FOREGROUND -> {
                // Foreground UI is active; keep background runtime running for real-time sync.
            }
            ACTION_APP_BACKGROUND -> {
                // App moved to background; ensure runtime is active.
                ensureDartRuntime()
                sendTick()
            }
        }
        startForeground(NOTIFICATION_ID, buildNotification())
        acquireWakeLock(120_000L)
        scheduleKeepAlive(applicationContext)
        WatchdogJobService.schedule(applicationContext)
        ServiceWatchdogWorker.schedule(applicationContext)
        ensureDartRuntime()
        scheduleStartupTick()
        sendTick()
        startWatchdog()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Schedule restart when task is removed from recents.
        UsageCollectorService.startService(applicationContext)
        scheduleKeepAlive(applicationContext, 2000L)
        scheduleRestart(applicationContext, 2000L)
        WatchdogJobService.schedule(applicationContext)
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        scheduleKeepAlive(applicationContext, 2000L)
        scheduleRestart(applicationContext, 2000L)
        stopWatchdog()
        releaseWakeLock()
        flutterEngine?.destroy()
        flutterEngine = null
        dartStarted = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureDartRuntime() {
        val engine = flutterEngine
        if (engine != null && engine.dartExecutor.isExecutingDart) {
            dartStarted = true
            return
        }
        flutterEngine?.destroy()
        flutterEngine = null
        backgroundChannel = null
        dartStarted = false
        lastEngineStartAt = 0L
        startDartBackgroundRuntime()
    }

    private fun startWatchdog() {
        if (watchdogStarted) {
            return
        }
        watchdogStarted = true
        watchdogHandler.postDelayed(watchdogRunnable, WATCHDOG_INTERVAL_MS)
    }

    private fun scheduleStartupTick() {
        if (startupScheduled) {
            return
        }
        startupScheduled = true
        watchdogHandler.postDelayed({
            startupScheduled = false
            ensureDartRuntime()
            sendTick()
        }, STARTUP_TICK_DELAY_MS)
    }

    private fun scheduleDelayedTick(delayMs: Long) {
        if (delayedTickScheduled) {
            return
        }
        delayedTickScheduled = true
        watchdogHandler.postDelayed({
            delayedTickScheduled = false
            ensureDartRuntime()
            sendTick()
        }, delayMs)
    }

    private fun acquireWakeLock(timeoutMs: Long) {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val existing = wakeLock
            if (existing != null && existing.isHeld) {
                existing.release()
            }
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "usage_collector:service_wakelock",
            ).apply {
                setReferenceCounted(false)
                acquire(timeoutMs)
            }
        } catch (_: Exception) {
            // ignore
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (_: Exception) {
            // ignore
        } finally {
            wakeLock = null
        }
    }

    private fun stopWatchdog() {
        watchdogStarted = false
        watchdogHandler.removeCallbacks(watchdogRunnable)
    }

    private fun startDartBackgroundRuntime() {
        if (dartStarted) {
            return
        }
        val flutterLoader = FlutterInjector.instance().flutterLoader()
        flutterLoader.startInitialization(applicationContext)
        flutterLoader.ensureInitializationComplete(applicationContext, null)

        val engine = FlutterEngine(applicationContext)
        GeneratedPluginRegistrant.registerWith(engine)
        NativeAppInventoryChannel.register(engine.dartExecutor.binaryMessenger, applicationContext)
        backgroundChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "usage_collector/background_service")
        lastEngineStartAt = SystemClock.elapsedRealtime()
        val entrypoint = DartExecutor.DartEntrypoint(
            flutterLoader.findAppBundlePath(),
            "backgroundServiceMain",
        )
        engine.dartExecutor.executeDartEntrypoint(entrypoint)
        flutterEngine = engine
        dartStarted = true
    }

    private fun sendTick() {
        val channel = backgroundChannel ?: return
        val now = SystemClock.elapsedRealtime()
        // Give the Dart isolate time to boot before pinging.
        if (lastEngineStartAt != 0L && now - lastEngineStartAt < ENGINE_WARMUP_MS) {
            val remaining =
                (ENGINE_WARMUP_MS - (now - lastEngineStartAt)).coerceAtLeast(1_000L)
            scheduleDelayedTick(remaining)
            return
        }
        try {
            channel.invokeMethod(
                "tick",
                null,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        lastTickOkAt = SystemClock.elapsedRealtime()
                    }
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        maybeRestartEngine()
                    }

                    override fun notImplemented() {
                        maybeRestartEngine()
                    }
                },
            )
        } catch (_: Exception) {
            maybeRestartEngine()
        }
    }

    private fun maybeRestartEngine() {
        val now = SystemClock.elapsedRealtime()
        val sinceOk = if (lastTickOkAt == 0L) Long.MAX_VALUE else now - lastTickOkAt
        val sinceStart = if (lastEngineStartAt == 0L) Long.MAX_VALUE else now - lastEngineStartAt
        // Restart only if Dart has been unresponsive for a while.
        if (sinceOk > 60_000L && sinceStart > 20_000L) {
            ensureDartRuntime()
        }
    }

    private fun stopBackgroundEngine() {
        stopWatchdog()
        releaseWakeLock()
        backgroundChannel = null
        flutterEngine?.destroy()
        flutterEngine = null
        dartStarted = false
        lastEngineStartAt = 0L
        lastTickOkAt = 0L
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            AndroidStrings.serviceChannelName(this),
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launchIntent =
            packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ulany\u015F")
            .setContentText(AndroidStrings.backgroundMonitoringActive(this))
            .setSmallIcon(R.drawable.app_icon_notification)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setOngoing(true)
            .build()
    }

}

