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

    @Volatile
    private var enabled = false

    fun configure(context: Context) {
        enabled = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    fun d(message: String) {
        if (enabled) Log.d(TAG, message)
    }

    fun w(message: String, error: Throwable? = null) {
        if (enabled) Log.w(TAG, message, error)
    }
}
