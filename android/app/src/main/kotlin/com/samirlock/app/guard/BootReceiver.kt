package com.samirlock.app.guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Brings protection back after the two events that otherwise leave it down.
 *
 * A reboot stops the guard, and so does updating Samir Lock itself: in both cases
 * protection would stay off until the user next opened the app, with locked apps
 * opening freely in the meantime. Does nothing unless the user switched
 * protection on and the required permissions are still granted.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        GuardLog.configure(context)
        GuardLog.d("boot: received ${intent.action}")

        if (intent.action !in RECOVERY_ACTIONS) return
        if (!GuardPreferences(context).isProtectionEnabled) {
            GuardLog.d("boot: protection is off, nothing to restore")
            return
        }

        // The safety net goes up first, and unconditionally. A reboot clears every
        // alarm the app had, so if this is not rescheduled here and the start
        // below is refused, nothing would ever try again and protection would stay
        // down until the user happened to open the app.
        GuardWatchdog.schedule(context)

        val started = GuardServiceController.start(context)
        GuardLog.d("boot: restore after ${intent.action} started=$started")

        if (!started) {
            // Boot is the busiest moment on the device; a refusal now is often
            // gone a few seconds later.
            GuardWatchdog.scheduleRetry(context, FIRST_RETRY_MS)
        }
    }

    private companion object {
        val RECOVERY_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            // Some OEM builds send this instead of BOOT_COMPLETED after a fast
            // boot. Harmless where it is never sent.
            "android.intent.action.QUICKBOOT_POWERON",
        )

        const val FIRST_RETRY_MS = 30_000L
    }
}
