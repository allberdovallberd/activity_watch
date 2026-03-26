package com.example.usage_collector

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.UserManager

object DeviceOwnerManager {
    fun applyPolicies(context: Context) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            ?: return
        if (!dpm.isDeviceOwnerApp(context.packageName)) {
            return
        }
        val admin = ComponentName(context, AppDeviceAdminReceiver::class.java)
        try {
            dpm.addUserRestriction(admin, UserManager.DISALLOW_APPS_CONTROL)
        } catch (_: Exception) {
            // ignore
        }
        try {
            dpm.addUserRestriction(admin, UserManager.DISALLOW_UNINSTALL_APPS)
        } catch (_: Exception) {
            // ignore
        }
        try {
            val field = UserManager::class.java.getField("DISALLOW_BATTERY_SAVER")
            val restriction = field.get(null) as? String
            if (!restriction.isNullOrBlank()) {
                dpm.addUserRestriction(admin, restriction)
            }
        } catch (_: Exception) {
            // ignore
        }
    }
}
