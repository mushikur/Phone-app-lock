package com.samirlock.app.inventory

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

/**
 * Rasterises launcher icons to PNG bytes for transport over the MethodChannel.
 *
 * Adaptive and vector icons have no backing bitmap, so they are drawn onto a
 * canvas at a fixed size; bitmap-backed icons take a cheaper scaling path.
 */
internal object IconEncoder {

    /** Edge length, in pixels, of the encoded icon. */
    const val ICON_SIZE_PX = 96

    fun encode(drawable: Drawable): ByteArray? {
        val bitmap = toBitmap(drawable) ?: return null
        return ByteArrayOutputStream().use { stream ->
            val compressed = bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            if (compressed) stream.toByteArray() else null
        }
    }

    private fun toBitmap(drawable: Drawable): Bitmap? {
        if (drawable is BitmapDrawable) {
            val source = drawable.bitmap ?: return null
            if (source.width == ICON_SIZE_PX && source.height == ICON_SIZE_PX) return source
            return Bitmap.createScaledBitmap(source, ICON_SIZE_PX, ICON_SIZE_PX, true)
        }

        return runCatching {
            val bitmap = Bitmap.createBitmap(ICON_SIZE_PX, ICON_SIZE_PX, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bitmap
        }.getOrNull()
    }
}
