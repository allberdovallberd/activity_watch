package com.example.usage_collector

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeAppInventoryChannel.register(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        super.onStart()
 
        UsageCollectorService.setAppInForeground(this, true)
        UsageCollectorService.startService(this)

        // ⚠️ was too aggressive (2 sec), increase slightly
        UsageCollectorService.scheduleKeepAlive(this, 60_000L)

        WatchdogJobService.schedule(this)
    }

    override fun onStop() {
        UsageCollectorService.setAppInForeground(this, false)
        super.onStop()
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            val packageName = packageName

            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        } catch (_: Exception) {
            // ignore
        }
    }
}
