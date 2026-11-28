package com.example.aurora_care

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
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
 * Avisos del cuidador (SCRUM-34). Misma lógica que PracticeNotifications
 * del adulto mayor: canal propio, AlarmManager y NotificationManager.
 * No usa servidor.
 *
 * A las 19:00, aunque la app esté cerrada:
 * - Domingo: resumen de la semana.
 * - Tres días sin prácticas nuevas: «Hace unos días que no practica».
 * - Si no hubo otro aviso y está activado: recordatorio diario.
 */
class CaregiverNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alerts = CaregiverNotifications(context)
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> {
                alerts.refresh()
                ElderNotifications(context).refresh()
            }
            ElderNotifications.ACTION -> ElderNotifications(context).deliver(intent)
            else -> alerts.deliverDaily(intent)
        }
    }
}

internal class CaregiverNotifications(private val context: Context) {
    private val prefs = context.getSharedPreferences("aurora_caregiver_alerts", Context.MODE_PRIVATE)
    private val alarms = context.getSystemService(AlarmManager::class.java)

    fun allowed(): Boolean {
        return (Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED) &&
            NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun configure(account: String?, enabled: Boolean, daily: Boolean,
                  lastPractice: Long?, days: List<String>) {
        val previous = prefs.getString("active", null)
        if (previous != account || !enabled) {
            for (id in allIds) NotificationManagerCompat.from(context).cancel(id)
        }
        prefs.edit()
            .putString("active", account)
            .putBoolean("enabled", enabled)
            .putBoolean("daily", daily)
            .putLong("lastPractice", if (account == null) 0L else lastPractice ?: 0L)
            .putStringSet("days", if (account == null) emptySet() else days.toSet())
            .apply()
        refresh()
    }

    fun refresh() {
        alarms.cancel(alarmIntent())
        if (activeAccount() == null) return
        schedule()
    }

    fun alert(account: String, kind: String, title: String, message: String): Boolean {
        if (activeAccount() != account) return false
        val id = when (kind) {
            "attention" -> attentionId
            "linked" -> linkedId
            "unlinked" -> unlinkedId
            "streak" -> streakId
            else -> progressId // "progress" y "new_area"
        }
        return notify(id, title, message)
    }

    fun deliverDaily(intent: Intent) {
        if (activeAccount() == null) return
        val today = Calendar.getInstance()
        if (intent.getStringExtra("day") == today.dayKey()) {
            var sent = false
            if (today.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY) sent = weeklySummary(today)
            if (inactivity(today)) sent = true
            if (!sent && prefs.getBoolean("daily", false)) {
                notify(dailyId, "¿Cómo va su familiar?",
                    "Puede revisar su actividad de práctica en el panel del cuidador.")
            }
        }
        schedule()
    }

    /** Resumen del domingo: días con práctica de lunes a domingo. */
    private fun weeklySummary(today: Calendar): Boolean {
        val week = "${today.get(Calendar.YEAR)}-${today.get(Calendar.WEEK_OF_YEAR)}"
        if (prefs.getString("weeklyFor", null) == week) return false
        prefs.edit().putString("weeklyFor", week).apply()
        val days = prefs.getStringSet("days", emptySet()) ?: emptySet()
        val count = (0..6).count { offset ->
            (today.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -offset) }.isoDay() in days
        }
        if (count == 0) return false // «Hace unos días que no practica» ya lo cubre
        val message = if (count == 1) {
            "Su familiar practicó 1 día esta semana. Puede ver el detalle en el panel."
        } else {
            "Su familiar practicó $count días esta semana. Puede ver el detalle en el panel."
        }
        return notify(weeklyId, "Resumen de la semana", message)
    }

    /** Avisa una sola vez cuando pasan tres días sin prácticas nuevas. */
    private fun inactivity(today: Calendar): Boolean {
        val last = prefs.getLong("lastPractice", 0L)
        if (last <= 0L || prefs.getLong("inactiveFor", 0L) == last) return false
        val lastDay = Calendar.getInstance().apply { timeInMillis = last }.startOfDay()
        val days = Math.round(
            ((today.clone() as Calendar).startOfDay().timeInMillis - lastDay.timeInMillis) / 86_400_000.0
        )
        if (days < inactiveDays) return false
        prefs.edit().putLong("inactiveFor", last).apply()
        return notify(inactiveId, "Hace unos días que no practica",
            "No vemos prácticas nuevas de su familiar hace $days días. " +
                "Si le viene bien, puede invitarle a jugar.")
    }

    private fun activeAccount(): String? =
        if (prefs.getBoolean("enabled", false) && allowed()) prefs.getString("active", null) else null

    private fun schedule() {
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, dailyHour)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_MONTH, 1)
        }
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, alarmIntent(target.dayKey()))
    }

    private fun alarmIntent(day: String? = null): PendingIntent =
        PendingIntent.getBroadcast(context, dailyId,
            Intent(context, CaregiverNotificationReceiver::class.java).apply {
                action = "com.example.aurora_care.CAREGIVER_ALERT"
                putExtra("day", day)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    /** Aviso al adulto mayor: su cuidador terminó el vínculo. */
    fun elderNotice(kind: String, title: String, message: String): Boolean =
        notify(if (kind == "linked") caregiverJoinedId else caregiverLeftId,
            title, message, linkChannel, "Vínculo familiar")

    private fun notify(id: Int, title: String, message: String,
                       channelId: String = channel,
                       channelName: String = "Avisos del cuidador"): Boolean {
        if (!allowed()) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_DEFAULT)
            )
            if (manager.getNotificationChannel(channelId)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        val open = PendingIntent.getActivity(context, 1,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return try {
            NotificationManagerCompat.from(context).notify(id,
                NotificationCompat.Builder(context, channelId)
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

    /** Mismo formato que el calendario de Flutter: aaaa-mm-dd. */
    private fun Calendar.isoDay(): String = String.format(Locale.ROOT, "%04d-%02d-%02d",
        get(Calendar.YEAR), get(Calendar.MONTH) + 1, get(Calendar.DAY_OF_MONTH))

    private fun Calendar.startOfDay(): Calendar = apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    companion object {
        private const val channel = "auroracare_caregiver"
        private const val progressId = 8201
        private const val attentionId = 8202
        private const val dailyId = 8203
        private const val linkedId = 8204
        private const val unlinkedId = 8205
        private const val streakId = 8206
        private const val inactiveId = 8207
        private const val weeklyId = 8208
        private const val caregiverLeftId = 8209
        private const val caregiverJoinedId = 8210
        private const val linkChannel = "auroracare_link"
        private val allIds = listOf(progressId, attentionId, dailyId, linkedId,
            unlinkedId, streakId, inactiveId, weeklyId)
        private const val dailyHour = 19
        private const val inactiveDays = 3

        /** Registra el canal "auroracare/caregiver_alerts" (se llama desde MainActivity). */
        fun register(context: Context, messenger: BinaryMessenger) {
            // Avisos extra del adulto mayor (16:00, 20:00 y domingo 18:00).
            ElderNotifications.register(context, messenger)
            val alerts = CaregiverNotifications(context)
            MethodChannel(messenger, "auroracare/caregiver_alerts")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "configure" -> {
                            alerts.configure(
                                call.argument<String>("account"),
                                call.argument<Boolean>("enabled") == true,
                                call.argument<Boolean>("daily") == true,
                                call.argument<Number>("lastPractice")?.toLong(),
                                call.argument<List<String>>("days") ?: emptyList(),
                            )
                            result.success(null)
                        }
                        "notify" -> {
                            val account = call.argument<String>("account")
                            val title = call.argument<String>("title")
                            val message = call.argument<String>("message")
                            result.success(
                                account != null && title != null && message != null &&
                                    alerts.alert(account, call.argument<String>("kind") ?: "progress", title, message)
                            )
                        }
                        "elder_notice" -> {
                            val title = call.argument<String>("title")
                            val message = call.argument<String>("message")
                            result.success(
                                title != null && message != null &&
                                    alerts.elderNotice(call.argument<String>("kind") ?: "left", title, message)
                            )
                        }
                        else -> result.notImplemented()
                    }
                }
        }
    }
}
