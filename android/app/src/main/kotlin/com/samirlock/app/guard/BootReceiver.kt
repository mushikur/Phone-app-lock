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
        if (intent.action !in RECOVERY_ACTIONS) return

        GuardLog.configure(context)
        if (!GuardPreferences(context).isProtectionEnabled) {
            GuardLog.d("boot: protection is off, nothing to restore")
            return
        }

        val started = GuardServiceController.start(context)
        GuardLog.d("boot: ${intent.action} restored protection, started=$started")

        // Arm the safety net even if the start was refused, so a later attempt
        // can recover.
        GuardWatchdog.schedule(context)
    }

    private companion object {
        val RECOVERY_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )
    }
}
