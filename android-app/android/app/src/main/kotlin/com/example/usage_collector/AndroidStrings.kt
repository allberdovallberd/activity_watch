package com.example.usage_collector

import android.content.Context

object AndroidStrings {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val LANGUAGE_CODE_KEY = "flutter.language_code"

    private fun languageCode(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return when (prefs.getString(LANGUAGE_CODE_KEY, "tr")?.lowercase()) {
            "en" -> "en"
            "ru" -> "ru"
            "tk" -> "tr"
            else -> "tr"
        }
    }

    fun serviceChannelName(context: Context): String =
        when (languageCode(context)) {
            "en" -> "Ulanyş Service"
            "ru" -> "Сервис Ulanyş"
            else -> "Ulanyş hyzmaty"
        }

    fun backgroundMonitoringActive(context: Context): String =
        when (languageCode(context)) {
            "en" -> "Background monitoring is active"
            "ru" -> "Фоновый мониторинг активен"
            else -> "Ulanyş maglumaty ýygnalýar"
        }

    fun deviceAdminExplanation(context: Context): String =
        when (languageCode(context)) {
            "en" -> "Required for stronger background persistence on institution devices."
            "ru" -> "Требуется для более устойчивой фоновой работы на устройствах организации."
            else -> "Institutyň enjamlarynyň fonda has durnukly işlemegi üçin zerur."
        }
}
