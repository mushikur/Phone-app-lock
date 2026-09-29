package com.samirlock.app.guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Brings protection back after a restart.
 *
 * Without this the guard service would stay down until the user opened the app
 * again, leaving locked apps open after every reboot. It does nothing unless the
 * user switched protection on and the required permissions are still granted.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!GuardPreferences(context).isProtectionEnabled) return

        GuardServiceController.start(context)
    }
}
