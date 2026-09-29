package com.samirlock.app.lock

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import com.samirlock.app.R
import com.samirlock.app.guard.GuardLog

/**
 * An opaque window placed over a protected app the instant a lock is decided.
 *
 * Starting an activity takes a couple of hundred milliseconds, and the protected
 * app is on screen for every one of them. Adding a window costs a frame, so this
 * covers the app immediately and is taken away once the real lock screen has
 * drawn. It is only ever a plain colour — no app content, no input handling
 * beyond swallowing touches meant for the app underneath.
 *
 * It uses the overlay permission that Samir Lock already requires to show the
 * lock screen at all, and it cannot become a trap: it removes itself after
 * [AUTO_HIDE_MS] whatever happens, so a lock screen that never arrives leaves the
 * user with their app rather than an immovable blank screen.
 */
object LockShield {

    /**
     * Long enough to cover any reasonable activity start, short enough that a
     * failure is a brief annoyance rather than a stuck phone.
     */
    private const val AUTO_HIDE_MS = 3_000L

    private val handler = Handler(Looper.getMainLooper())
    private val autoHide = Runnable {
        GuardLog.w("shield: lock screen never appeared, uncovering")
        hide()
    }

    private var shieldView: View? = null

    /** Covers the screen. Safe to call when already showing. */
    fun show(context: Context) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.post { show(context) }
            return
        }

        if (!Settings.canDrawOverlays(context)) {
            GuardLog.w("shield: no overlay permission, cannot cover the app")
            return
        }

        if (shieldView != null) {
            rearmAutoHide()
            return
        }

        val windowManager = context.getSystemService(WindowManager::class.java) ?: return
        val view = runCatching {
            LayoutInflater.from(context).inflate(R.layout.view_lock_shield, null)
        }.getOrNull() ?: return

        runCatching { windowManager.addView(view, layoutParams()) }
            .onSuccess {
                shieldView = view
                rearmAutoHide()
                GuardLog.d("shield: covering the app")
            }
            .onFailure { GuardLog.w("shield: could not cover the app", it) }
    }

    /** Uncovers the screen. Safe to call when nothing is showing. */
    fun hide() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.post { hide() }
            return
        }

        handler.removeCallbacks(autoHide)
        val view = shieldView ?: return
        shieldView = null

        val windowManager = view.context.getSystemService(WindowManager::class.java)
        runCatching { windowManager?.removeViewImmediate(view) }
            .onSuccess { GuardLog.d("shield: uncovered") }
            .onFailure { GuardLog.w("shield: could not uncover", it) }
    }

    private fun rearmAutoHide() {
        handler.removeCallbacks(autoHide)
        handler.postDelayed(autoHide, AUTO_HIDE_MS)
    }

    private fun layoutParams(): WindowManager.LayoutParams {
        @Suppress("DEPRECATION")
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            // Not focusable, so it never takes input away from the lock screen
            // coming up behind it, but deliberately touchable so taps cannot reach
            // the protected app underneath. Laid out past the system bars so the
            // cover is complete.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_SECURE,
            PixelFormat.OPAQUE,
        )
    }
}
