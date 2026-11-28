package com.example.aurora_care

import android.Manifest
import android.app.Activity
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File
import java.io.OutputStream
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val privacyActions by lazy { PrivacyActions(this) }
    private val profilePhotoPicker by lazy { ProfilePhotoPicker(this) }
    private data class PendingReport(val text: String, val activity: Map<String, Int>, val sections: List<Map<String, Any>>, val result: MethodChannel.Result)
    private var pendingReport: PendingReport? = null
    private val saveReportRequest = 7421
    private val notificationRequest = 7422
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        privacyActions.register(flutterEngine.dartExecutor.binaryMessenger)
        registerPracticeChannel(flutterEngine)
        CaregiverNotifications.register(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "auroracare/profile_photo")
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") profilePhotoPicker.pick(result) else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "auroracare/report_pdf")
            .setMethodCallHandler { call, result ->
                val text = call.argument<String>("text")
                val activity = call.argument<Map<String, Int>>("activity") ?: emptyMap()
                val sections = call.argument<List<Map<String, Any>>>("sections") ?: emptyList()
                when {
                    call.method !in setOf("save", "share") -> result.notImplemented()
                    text.isNullOrBlank() -> result.error("empty", "Informe vacío", null)
                    pendingReport != null -> result.error("busy", "Guardado en curso", null)
                    call.method == "share" -> shareReport(text, activity, sections, result)
                    else -> {
                        pendingReport = PendingReport(text, activity, sections, result)
                        try {
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/pdf"
                                putExtra(Intent.EXTRA_TITLE, "AuroraCare-informe-de-practicas.pdf")
                            }, saveReportRequest)
                        } catch (_: Exception) {
                            pendingReport = null
                            result.error("picker", "No se pudo abrir el selector", null)
                        }
                    }
                }
            }
    }

    private fun registerPracticeChannel(engine: FlutterEngine) {
        val alerts = PracticeNotifications(this)
        MethodChannel(engine.dartExecutor.binaryMessenger, "auroracare/practice_feedback")
            .setMethodCallHandler { call, result ->
                val account = call.argument<String>("account")
                when (call.method) {
                    "permission" -> result.success(alerts.allowed())
                    "requestPermission" -> {
                        if (alerts.allowed()) {
                            result.success(true)
                        } else if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            android.content.pm.PackageManager.PERMISSION_GRANTED) {
                            if (permissionResult != null) {
                                result.success(false)
                            } else {
                                permissionResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequest)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "configure" -> {
                        alerts.configure(account, call.argument<Boolean>("enabled") == true)
                        result.success(null)
                    }
                    "practice" -> {
                        val at = call.argument<Number>("at")?.toLong()
                        if (account != null && at != null) alerts.practiced(account, at)
                        result.success(null)
                    }
                    "report" -> {
                        val at = call.argument<Number>("at")?.toLong()
                        if (account != null && at != null) alerts.reportReady(account, at)
                        result.success(null)
                    }
                    "touchFeedbackEnabled" -> result.success(
                        Settings.System.getInt(contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) != 0
                    )
                    "soundSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
                        } catch (_: android.content.ActivityNotFoundException) {
                            startActivity(Intent(Settings.ACTION_SETTINGS))
                        }
                        result.success(null)
                    }
                    "settings" -> {
                        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        result.success(null)
                    }
                    "sound" -> {
                        try {
                            val tone = ToneGenerator(AudioManager.STREAM_MUSIC, 35)
                            tone.startTone(ToneGenerator.TONE_PROP_ACK, 160)
                            Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 220)
                        } catch (_: RuntimeException) {
                            // El dispositivo puede no tener salida de audio disponible.
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationRequest) {
            permissionResult?.success(PracticeNotifications(this).allowed())
            permissionResult = null
        }
    }

    @Deprecated("Callback del selector de documentos de Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == privacyActions.requestCode) {
            privacyActions.finish(resultCode, data?.data)
            return
        }
        if (requestCode == profilePhotoPicker.requestCode) {
            profilePhotoPicker.finish(resultCode, data?.data)
            return
        }
        if (requestCode != saveReportRequest) return
        val (text, activity, sections, result) = pendingReport ?: return
        pendingReport = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }
        try {
            val output = checkNotNull(contentResolver.openOutputStream(uri, "wt"))
            output.use { writePdf(it, text, activity, sections) }
            result.success(true)
        } catch (_: Exception) {
            result.error("write", "No se pudo guardar el PDF", null)
        }
    }

    private fun shareReport(text: String, activity: Map<String, Int>, sections: List<Map<String, Any>>, result: MethodChannel.Result) {
        try {
            val folder = File(cacheDir, "report_exports").apply { mkdirs() }
            val file = File.createTempFile("AuroraCare-informe-", ".pdf", folder)
            file.outputStream().use { writePdf(it, text, activity, sections) }
            val uri = FileProvider.getUriForFile(this, "$packageName.report_files", file)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = android.content.ClipData.newUri(contentResolver, "Informe de AuroraCare", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(send, "Compartir informe"))
            result.success(true)
        } catch (_: Exception) {
            result.error("share", "No se pudo compartir el PDF", null)
        }
    }

    private fun writePdf(output: OutputStream, text: String, activity: Map<String, Int>, sections: List<Map<String, Any>>) {
        val pdf = PdfDocument()
        try {
            if (sections.isNotEmpty()) {
                ReportPdfWriter(pdf).write(sections, activity)
            } else {
                writeReport(pdf, text, activity)
            }
            pdf.writeTo(output)
        } finally {
            pdf.close()
        }
    }

    private fun writeReport(pdf: PdfDocument, text: String, activity: Map<String, Int>) {
        val bodyPaint = TextPaint(TextPaint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(39, 33, 62)
            textSize = 12f
        }
        val headingPaint = TextPaint(bodyPaint).apply {
            color = Color.rgb(59, 47, 114)
            textSize = 19f
            typeface = Typeface.DEFAULT_BOLD
        }
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, bodyPaint, 499)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setLineSpacing(3f, 1f)
            .build()
        var line = 0
        var pageNumber = 1
        while (line < layout.lineCount) {
            val bodyTop = if (pageNumber == 1 && activity.isNotEmpty()) 220f else 82f
            val availableHeight = 767 - bodyTop.toInt()
            val top = layout.getLineTop(line)
            var end = line + 1
            while (end < layout.lineCount && layout.getLineBottom(end) - top <= availableHeight) end++
            val page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, pageNumber).create())
            val canvas = page.canvas
            canvas.drawText("AuroraCare | Informe de prácticas", 48f, 55f, headingPaint)
            if (pageNumber == 1 && activity.isNotEmpty()) {
                canvas.drawText("Actividad por área · cantidad de prácticas", 48f, 85f, bodyPaint)
                val maxCount = (activity.values.maxOrNull() ?: 0).coerceAtLeast(1)
                activity.entries.take(3).forEachIndexed { index, entry ->
                    val y = 108f + index * 32f
                    canvas.drawText("${entry.key}: ${entry.value}", 48f, y, bodyPaint)
                    val barPaint = android.graphics.Paint().apply { color = Color.rgb(237, 232, 249) }
                    canvas.drawRoundRect(190f, y - 10f, 547f, y + 2f, 5f, 5f, barPaint)
                    barPaint.color = Color.rgb(94, 72, 188)
                    val width = 357f * entry.value.coerceAtLeast(0) / maxCount
                    if (width > 0) canvas.drawRoundRect(190f, y - 10f, 190f + width, y + 2f, 5f, 5f, barPaint)
                }
            }
            canvas.save()
            canvas.clipRect(48f, bodyTop, 547f, bodyTop + layout.getLineBottom(end - 1) - top)
            canvas.translate(48f, bodyTop - top)
            layout.draw(canvas)
            canvas.restore()
            canvas.drawText("AuroraCare · Página $pageNumber", 48f, 800f, bodyPaint)
            pdf.finishPage(page)
            line = end
            pageNumber++
        }
    }
}
