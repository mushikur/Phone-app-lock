package com.samirlock.app.auth

import android.content.Context

/**
 * Remembers consecutive wrong PIN attempts across process death.
 *
 * Kept in the app's private storage and never exposed over the bridge, so the
 * Flutter layer cannot reset it. Holds no secret — only a count and a timestamp.
 */
class LockoutStore(context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    val failedAttempts: Int
        get() = prefs.getInt(KEY_FAILED_ATTEMPTS, 0)

    /**
     * Milliseconds still to wait, or 0 when an attempt is allowed now.
     *
     * A clock moved backwards would otherwise leave a lockout hanging far into
     * the future, so an end time further away than the longest possible delay is
     * treated as expired.
     */
    fun remainingLockoutMs(nowMs: Long = System.currentTimeMillis()): Long {
        val until = prefs.getLong(KEY_LOCKED_UNTIL, 0L)
        val remaining = until - nowMs
        return when {
            remaining <= 0L -> 0L
            remaining > LockoutPolicy.delayAfter(Int.MAX_VALUE) -> 0L
            else -> remaining
        }
    }

    /** Records a wrong attempt and returns the delay now owed, in milliseconds. */
    fun recordFailure(nowMs: Long = System.currentTimeMillis()): Long {
        val attempts = failedAttempts + 1
        val delay = LockoutPolicy.delayAfter(attempts)

        prefs.edit()
            .putInt(KEY_FAILED_ATTEMPTS, attempts)
            .putLong(KEY_LOCKED_UNTIL, if (delay > 0L) nowMs + delay else 0L)
            .apply()

        return delay
    }

    /** Clears the count after a successful unlock. */
    fun recordSuccess() {
        prefs.edit()
            .remove(KEY_FAILED_ATTEMPTS)
            .remove(KEY_LOCKED_UNTIL)
            .apply()
    }

    private companion object {
        const val PREFS_NAME = "samir_lock_secure"
        const val KEY_FAILED_ATTEMPTS = "failed_attempts"
        const val KEY_LOCKED_UNTIL = "locked_until"
    }
}
