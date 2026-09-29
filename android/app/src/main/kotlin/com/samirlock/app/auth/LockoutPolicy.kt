package com.samirlock.app.auth

/**
 * How long to wait after repeated wrong PINs.
 *
 * Pure Kotlin, no Android imports: the numbers that decide whether the owner of
 * the phone can get back in deserve to be readable in one screen.
 *
 * The delay grows but is capped, and there is deliberately no permanent lockout
 * and no data wipe — this protects against someone tapping guesses, not against
 * a determined attacker with the handset, and it must never leave the legitimate
 * owner shut out of their own apps.
 */
object LockoutPolicy {

    /** Wrong attempts allowed before any delay is applied. */
    const val FREE_ATTEMPTS = 4

    private const val FIRST_DELAY_MS = 30_000L
    private const val MAX_DELAY_MS = 300_000L

    /**
     * The delay owed after [failedAttempts] consecutive wrong PINs.
     *
     * 30s, then 60s, then 120s, capped at 5 minutes.
     */
    fun delayAfter(failedAttempts: Int): Long {
        if (failedAttempts <= FREE_ATTEMPTS) return 0L

        val step = failedAttempts - FREE_ATTEMPTS - 1
        if (step >= 31) return MAX_DELAY_MS

        val delay = FIRST_DELAY_MS shl step
        return if (delay <= 0L || delay > MAX_DELAY_MS) MAX_DELAY_MS else delay
    }

    /** Attempts left before the next delay, or 0 once delays have started. */
    fun attemptsBeforeDelay(failedAttempts: Int): Int =
        (FREE_ATTEMPTS - failedAttempts).coerceAtLeast(0)
}
