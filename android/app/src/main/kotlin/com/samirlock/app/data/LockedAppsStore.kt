package com.samirlock.app.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Local, offline-only store for the set of packages the user chose to lock.
 *
 * Kotlin owns this state: the guard service introduced in a later phase reads it
 * on every foreground change, so Flutter only ever mirrors it through the bridge.
 * Backed by plain [SharedPreferences] because the set holds no secrets — PINs and
 * biometric material never come here.
 */
class LockedAppsStore(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Packages currently marked as locked. */
    fun lockedPackages(): Set<String> =
        prefs.getStringSet(KEY_LOCKED_PACKAGES, emptySet())?.toSet() ?: emptySet()

    /**
     * Marks [packageName] as locked or unlocked and returns the resulting state,
     * so the caller can reconcile its own optimistic update.
     */
    fun setLocked(packageName: String, locked: Boolean): Boolean {
        val updated = lockedPackages().toMutableSet()
        val changed = if (locked) updated.add(packageName) else updated.remove(packageName)
        if (changed) {
            prefs.edit().putStringSet(KEY_LOCKED_PACKAGES, updated).apply()
        }
        return locked
    }

    private companion object {
        const val PREFS_NAME = "samir_lock_preferences"
        const val KEY_LOCKED_PACKAGES = "locked_packages"
    }
}
