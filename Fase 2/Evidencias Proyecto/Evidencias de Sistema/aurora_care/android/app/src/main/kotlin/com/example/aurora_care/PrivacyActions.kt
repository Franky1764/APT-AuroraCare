package com.example.aurora_care

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class PrivacyActions(private val activity: Activity) {
    val requestCode = 7425
    private var pending: Pair<String, MethodChannel.Result>? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "auroracare/privacy").setMethodCallHandler { call, result ->
            when (call.method) {
                "clearReminders" -> {
                    val account = call.argument<String>("account")
                    if (account == null) {
                        result.error("account", "Se necesita una cuenta", null)
                    } else {
                        val practice = activity.getSharedPreferences(
                            "aurora_practice_alerts", android.content.Context.MODE_PRIVATE
                        )
                        val removed = practice.edit()
                            .remove("practiced_$account")
                            .remove("report_$account")
                            .commit()
                        val caregiver = activity.getSharedPreferences(
                            "aurora_caregiver_alerts", android.content.Context.MODE_PRIVATE
                        )
                        val caregiverRemoved = if (caregiver.getString("active", null) == account) {
                            caregiver.edit().remove("weeklyFor").remove("inactiveFor").commit()
                        } else true
                        if (removed && caregiverRemoved) result.success(null)
                        else result.error("storage", "No se pudieron borrar los avisos", null)
                    }
                }
                "email" -> {
                    val subject = call.argument<String>("subject") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val uri = Uri.parse("mailto:auroracareprivacidad@gmail.com").buildUpon()
                        .appendQueryParameter("subject", subject)
                        .appendQueryParameter("body", body)
                        .build()
                    try {
                        activity.startActivity(Intent(Intent.ACTION_SENDTO, uri))
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                "save" -> {
                    val text = call.argument<String>("text")
                    if (text == null || pending != null) {
                        result.error("unavailable", "No se puede iniciar el guardado", null)
                    } else {
                        pending = text to result
                        try {
                            activity.startActivityForResult(
                                Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "application/json"
                                    putExtra(Intent.EXTRA_TITLE, "AuroraCare-mis-datos.json")
                                }, requestCode
                            )
                        } catch (_: ActivityNotFoundException) {
                            pending = null
                            result.error("picker", "No se pudo abrir el selector", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun finish(resultCode: Int, uri: Uri?) {
        val (text, result) = pending ?: return
        pending = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }
        try {
            checkNotNull(activity.contentResolver.openOutputStream(uri, "wt")).use {
                it.write(text.toByteArray(Charsets.UTF_8))
            }
            result.success(true)
        } catch (_: Exception) {
            result.error("write", "No se pudo guardar la copia", null)
        }
    }
}
