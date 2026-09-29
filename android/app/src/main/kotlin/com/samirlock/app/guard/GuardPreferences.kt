package com.samirlock.app.guard

import android.content.Context

/**
 * Whether the user has switched protection on.
 *
 * Shares the app's preference file with the locked-app list; both are plain local
 * settings and hold no secrets.
 */
class GuardPreferences(context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var isProtectionEnabled: Boolean
        get() = prefs.getBoolean(KEY_PROTECTION_ENABLED, false)
        set(value) = prefs.edit().putBoolean(KEY_PROTECTION_ENABLED, value).apply()

    /**
     * Whether the lock screen offers fingerprint or face unlock.
     *
     * A convenience preference, not a security decision: the PIN is required
     * either way, and the lock screen reads this natively rather than being told
     * what to do by the Flutter layer. On by default, because a user who has
     * enrolled a fingerprint expects it to work.
     */
    var isBiometricEnabled: Boolean
        get() = prefs.getBoolean(KEY_BIOMETRIC_ENABLED, true)
        set(value) = prefs.edit().putBoolean(KEY_BIOMETRIC_ENABLED, value).apply()

    private companion object {
        const val PREFS_NAME = "samir_lock_preferences"
        const val KEY_PROTECTION_ENABLED = "protection_enabled"
        const val KEY_BIOMETRIC_ENABLED = "biometric_enabled"
    }
}
