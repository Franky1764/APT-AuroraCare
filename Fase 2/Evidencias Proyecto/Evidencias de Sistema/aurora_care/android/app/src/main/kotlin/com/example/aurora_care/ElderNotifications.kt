package com.example.aurora_care

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.Locale

/**
 * Avisos extra del adulto mayor. Los de las 09:00 («Un desafío para hoy») y
 * 20:00 («Un momento para usted») siguen en PracticeNotifications.
 *
 * - 16:00 Sugerencia de área, solo si hoy no practicó.
 * - 20:00 Felicitación por constancia, solo si hoy practicó y es un hito
 *   (3, 5, 7, 14, 21, 28 días seguidos). Nunca coincide con el recordatorio.
 * - Domingo 18:00 Resumen de la semana.
 *
 * Las alarmas las recibe CaregiverNotificationReceiver (ya está en el
 * AndroidManifest), con la acción ELDER_ALERT.
 */
internal class ElderNotifications(private val context: Context) {
    private val prefs = context.getSharedPreferences("aurora_elder_alerts", Context.MODE_PRIVATE)
    private val alarms = context.getSystemService(AlarmManager::class.java)

    private fun allowed(): Boolean =
        (Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED) &&
            NotificationManagerCompat.from(context).areNotificationsEnabled()

    fun configure(account: String?, enabled: Boolean, days: List<String>, area: String?) {
        if (prefs.getString("active", null) != account || !enabled) {
            for (id in alarmIds) NotificationManagerCompat.from(context).cancel(id)
        }
        prefs.edit()
            .putString("active", account)
            .putBoolean("enabled", enabled)
            .putStringSet("days", if (account == null) emptySet() else days.toSet())
            .putString("area", area)
            .apply()
        refresh()
    }

    fun refresh() {
        for (id in alarmIds) alarms.cancel(alarmIntent(id))
        if (activeAccount() == null) return
        schedule(areaId, 16)
        schedule(streakId, 20)
        schedule(weeklyId, 18, Calendar.SUNDAY)
    }

    fun deliver(intent: Intent) {
        if (activeAccount() == null) return
        val id = intent.getIntExtra("kind", 0)
        val now = Calendar.getInstance()
        if (intent.getStringExtra("day") == now.dayKey()) {
            val days = prefs.getStringSet("days", emptySet()) ?: emptySet()
            val practicedToday = now.isoDay() in days
            when (id) {
                areaId -> if (!practicedToday) {
                    val area = prefs.getString("area", null)
                    if (area != null) {
                        notify(id, "¿Probamos algo distinto?",
                            "Hace unos días que no juega $area. Si le apetece, hoy puede intentarlo.")
                    } else {
                        notify(id, "Una pausa para jugar",
                            "Si tiene un momento esta tarde, puede practicar un ratito.")
                    }
                }
                streakId -> if (practicedToday) {
                    val streak = streak(days, now)
                    val milestone = streak == 3 || streak == 5 || (streak >= 7 && streak % 7 == 0)
                    if (milestone && prefs.getString("streakFor", null) != now.dayKey()) {
                        prefs.edit().putString("streakFor", now.dayKey()).apply()
                        notify(id, "¡Muy bien! 👏",
                            "Lleva $streak días seguidos practicando. ¡Siga así!")
                    }
                }
                weeklyId -> {
                    val count = (0..6).count { offset ->
                        (now.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -offset) }.isoDay() in days
                    }
                    if (count > 0) {
                        val text = if (count == 1) "1 día" else "$count días"
                        notify(id, "Resumen de su semana",
                            "Esta semana practicó $text. ¡Siga así!")
                    }
                }
            }
        }
        refresh()
    }

    private fun streak(days: Set<String>, now: Calendar): Int {
        var count = 0
        val day = now.clone() as Calendar
        while (day.isoDay() in days) {
            count++
            day.add(Calendar.DAY_OF_MONTH, -1)
        }
        return count
    }

    private fun activeAccount(): String? =
        if (prefs.getBoolean("enabled", false) && allowed()) prefs.getString("active", null) else null

    /** Próxima vez a [hour]:00; con [weekday], solo ese día de la semana. */
    private fun schedule(id: Int, hour: Int, weekday: Int? = null) {
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_MONTH, 1)
            if (weekday != null) {
                while (get(Calendar.DAY_OF_WEEK) != weekday) add(Calendar.DAY_OF_MONTH, 1)
            }
        }
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis,
            alarmIntent(id, target.dayKey()))
    }

    private fun alarmIntent(id: Int, day: String? = null): PendingIntent =
        PendingIntent.getBroadcast(context, id,
            Intent(context, CaregiverNotificationReceiver::class.java).apply {
                action = ACTION
                putExtra("kind", id)
                putExtra("day", day)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun notify(id: Int, title: String, message: String): Boolean {
        if (!allowed()) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(channel, "Ánimo y resumen", NotificationManager.IMPORTANCE_DEFAULT)
            )
            if (manager.getNotificationChannel(channel)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        val open = PendingIntent.getActivity(context, 2,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return try {
            NotificationManagerCompat.from(context).notify(id,
                NotificationCompat.Builder(context, channel)
                    .setSmallIcon(R.drawable.ic_notification)
                    .setColor(0xFF5B4BB5.toInt())
                    .setContentTitle(title)
                    .setContentText(message)
                    .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                    .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                    .setContentIntent(open)
                    .setAutoCancel(true)
                    .build())
            true
        } catch (_: SecurityException) {
            false
        }
    }

    private fun Calendar.dayKey(): String =
        "${get(Calendar.YEAR)}-${get(Calendar.DAY_OF_YEAR)}"

    private fun Calendar.isoDay(): String = String.format(Locale.ROOT, "%04d-%02d-%02d",
        get(Calendar.YEAR), get(Calendar.MONTH) + 1, get(Calendar.DAY_OF_MONTH))

    companion object {
        const val ACTION = "com.example.aurora_care.ELDER_ALERT"
        private const val channel = "auroracare_elder_cheer"
        private const val areaId = 8301
        private const val streakId = 8302
        private const val weeklyId = 8303
        private val alarmIds = listOf(areaId, streakId, weeklyId)

        /** Canal "auroracare/elder_alerts" (lo registra CaregiverNotifications.register). */
        fun register(context: Context, messenger: BinaryMessenger) {
            val alerts = ElderNotifications(context)
            MethodChannel(messenger, "auroracare/elder_alerts")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "configure" -> {
                            alerts.configure(
                                call.argument<String>("account"),
                                call.argument<Boolean>("enabled") == true,
                                call.argument<List<String>>("days") ?: emptyList(),
                                call.argument<String>("area"),
                            )
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
        }
    }
}
