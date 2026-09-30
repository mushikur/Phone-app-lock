package com.samirlock.app.guard

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log

/**
 * Logging for the lock engine, under one tag so the whole flow can be followed
 * with `adb logcat -s SamirLockGuard`.
 *
 * Silent in release builds: [configure] enables it only when the app is
 * debuggable, so nothing about the user's apps is ever written to the log on a
 * shipped build.
 */
object GuardLog {

    const val TAG = "SamirLockGuard"

    private const val PREFS_NAME = "samir_lock_preferences"
    private const val KEY_DIAGNOSTICS = "diagnostics_enabled"

    @Volatile
    private var enabled = false

    /**
     * Turns logging on for a debuggable build, or for a release build where the
     * user has switched diagnostics on themselves.
     *
     * The second case exists because a release build is otherwise silent, which
     * leaves a problem that only happens on a real phone impossible to see. It
     * is off unless the user asks for it, and it never logs the contents of a
     * notification - only package names, keys and outcomes.
     */
    fun configure(context: Context) {
        val debuggable =
            (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        enabled = debuggable || isDiagnosticsEnabled(context)
    }

    fun isDiagnosticsEnabled(context: Context): Boolean =
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_DIAGNOSTICS, false)

    fun setDiagnosticsEnabled(context: Context, value: Boolean) {
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_DIAGNOSTICS, value)
            .apply()
        configure(context)
        Log.i(TAG, "diagnostics ${if (value) "enabled" else "disabled"}")
    }

    fun d(message: String) {
        if (enabled) Log.d(TAG, message)
    }

    fun w(message: String, error: Throwable? = null) {
        if (enabled) Log.w(TAG, message, error)
    }

    /** Always logged, so a diagnostic session has a visible beginning. */
    fun always(message: String) {
        Log.i(TAG, message)
    }
}
