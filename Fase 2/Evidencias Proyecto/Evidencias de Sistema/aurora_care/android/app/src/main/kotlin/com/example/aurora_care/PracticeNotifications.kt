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
import java.util.Calendar

class PracticeNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alerts = PracticeNotifications(context)
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> alerts.refresh()
            else -> alerts.deliver(intent)
        }
    }
}

internal class PracticeNotifications(private val context: Context) {
    private val prefs = context.getSharedPreferences("aurora_practice_alerts", Context.MODE_PRIVATE)
    private val alarms = context.getSystemService(AlarmManager::class.java)

    fun allowed(): Boolean {
        return (Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED) &&
            NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun configure(account: String?, enabled: Boolean) {
        val previous = prefs.getString("active", null)
        if (previous != account || !enabled) {
            for (id in listOf(challengeId, reminderId, reportId)) {
                NotificationManagerCompat.from(context).cancel(id)
            }
        }
        prefs.edit().putString("active", account).putBoolean("enabled", enabled).apply()
        refresh()
    }

    fun refresh() {
        for (id in listOf(challengeId, reminderId)) {
            alarms.cancel(alarmIntent(id))
        }
        if (activeAccount() == null) return
        schedule(challengeId, 9)
        schedule(reminderId, 20)
    }

    fun practiced(account: String, at: Long) {
        val day = Calendar.getInstance().apply { timeInMillis = at }.dayKey()
        prefs.edit().putString("practiced_$account", day).apply()
        if (activeAccount() == account && day == Calendar.getInstance().dayKey()) {
            NotificationManagerCompat.from(context).cancel(reminderId)
        }
    }

    fun reportReady(account: String, latestPractice: Long) {
        if (activeAccount() != account ||
            latestPractice <= prefs.getLong("report_$account", 0L)) return
        if (notify(reportId, "Su informe está listo",
                "Puede consultarlo en Mi progreso cuando quiera.")) {
            prefs.edit().putLong("report_$account", latestPractice).apply()
        }
    }

    fun deliver(intent: Intent) {
        val account = activeAccount() ?: return
        val id = intent.getIntExtra("kind", 0)
        val now = Calendar.getInstance()
        if (intent.getStringExtra("day") == now.dayKey()) {
            when (id) {
                challengeId -> notify(id, "Un desafío para hoy",
                    "Su desafío del día está disponible. Puede hacerlo a su ritmo.")
                reminderId -> if (prefs.getString("practiced_$account", null) != now.dayKey()) {
                    notify(id, "Un momento para usted",
                        "Si le apetece, todavía tiene tiempo para practicar hoy.")
                }
            }
        }
        if (id == challengeId || id == reminderId) schedule(id, if (id == challengeId) 9 else 20)
    }

    private fun activeAccount(): String? =
        if (prefs.getBoolean("enabled", false) && allowed()) prefs.getString("active", null) else null

    private fun schedule(id: Int, hour: Int) {
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_MONTH, 1)
        }
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, alarmIntent(id, target.dayKey()))
    }

    private fun alarmIntent(id: Int, day: String? = null): PendingIntent =
        PendingIntent.getBroadcast(context, id,
            Intent(context, PracticeNotificationReceiver::class.java).apply {
                action = "com.example.aurora_care.PRACTICE_ALERT"
                putExtra("kind", id)
                putExtra("day", day)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun notify(id: Int, title: String, message: String): Boolean {
        if (!allowed()) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(channel, "Prácticas e informes", NotificationManager.IMPORTANCE_DEFAULT)
            )
            if (manager.getNotificationChannel(channel)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        val open = PendingIntent.getActivity(context, 0,
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

    private companion object {
        const val channel = "auroracare_practice"
        const val challengeId = 8101
        const val reminderId = 8102
        const val reportId = 8103
    }
}
