package com.example.aurora_care

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.math.max

internal class ProfilePhotoPicker(private val activity: Activity) {
    val requestCode = 7423
    private var pending: MethodChannel.Result? = null

    @Suppress("DEPRECATION")
    fun pick(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Ya está eligiendo una foto", null)
            return
        }
        pending = result
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                try {
                    activity.startActivityForResult(
                        Intent(MediaStore.ACTION_PICK_IMAGES).setType("image/*"), requestCode
                    )
                    return
                } catch (_: ActivityNotFoundException) {
                    // Algunos dispositivos no incluyen el selector de fotos.
                }
            }
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
            }, requestCode)
        } catch (_: Exception) {
            pending = null
            result.error("picker", "No se pudo abrir el selector de fotos", null)
        }
    }

    fun finish(resultCode: Int, uri: Uri?) {
        val result = pending ?: return
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null
            result.success(null)
            return
        }
        Thread {
            val bytes = runCatching { encodePhoto(uri) }.getOrNull()
            activity.runOnUiThread {
                pending = null
                if (bytes == null) {
                    result.error("photo", "No se pudo leer la imagen", null)
                } else {
                    result.success(bytes)
                }
            }
        }.start()
    }

    private fun encodePhoto(uri: Uri): ByteArray {
        val resolver = activity.contentResolver
        val bitmap = if (Build.VERSION.SDK_INT >= 28) {
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(resolver, uri)) { decoder, info, _ ->
                val size = info.size
                val scale = minOf(1.0, 480.0 / max(size.width, size.height))
                decoder.setTargetSize(
                    max(1, (size.width * scale).toInt()),
                    max(1, (size.height * scale).toInt())
                )
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        } else {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            resolver.openInputStream(uri).use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            while (max(bounds.outWidth, bounds.outHeight) / sample > 480) sample *= 2
            val options = BitmapFactory.Options().apply { inSampleSize = sample }
            checkNotNull(resolver.openInputStream(uri).use { BitmapFactory.decodeStream(it, null, options) })
        }
        return try {
            ByteArrayOutputStream().use { output ->
                check(bitmap.compress(Bitmap.CompressFormat.JPEG, 80, output))
                output.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }
}
