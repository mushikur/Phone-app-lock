package com.samirlock.app.guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Wakes on the watchdog alarm and puts the guard back up if it is down.
 *
 * Does nothing at all when protection is off or already running, so the common
 * case costs one preference read.
 */
class GuardWatchdogReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        GuardLog.configure(context)

        if (GuardServiceController.isRunning()) {
            GuardLog.d("watchdog: guard is up, nothing to do")
            return
        }

        val restarted = GuardServiceController.startIfEnabled(context)
        GuardLog.d("watchdog: guard was down, restarted=$restarted")
    }
}
