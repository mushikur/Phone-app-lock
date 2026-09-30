package com.samirlock.app.notifications

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.samirlock.app.guard.GuardLog

/**
 * Takes the user to the page where an app's pop-up notifications are turned off.
 *
 * Samir Lock cannot change another app's notification settings — that needs a
 * system permission no installable app can hold — so the most it can do is land
 * the user on exactly the right screen in one tap.
 *
 * The channel-level page is tried first because it is the one with the alert
 * setting on it. Some builds redirect that to the app-level page, so that is the
 * fallback, and app details is the last resort.
 */
object PopupSettingsLauncher {

    /** @return true when a settings page was opened. */
    fun open(
        context: Context,
        activity: Activity?,
        packageName: String,
        channelId: String,
    ): Boolean {
        val launcher: Context = activity ?: context
        val candidates = mutableListOf<Intent>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && channelId.isNotEmpty()) {
            candidates += Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
        }

        candidates += Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)

        candidates += Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", packageName, null))

        for (intent in candidates) {
            if (activity == null) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(context.packageManager) == null) continue

            if (runCatching { launcher.startActivity(intent) }.isSuccess) {
                GuardLog.d("popup: opened ${intent.action} for $packageName")
                return true
            }
        }

        GuardLog.w("popup: no settings page would open for $packageName")
        return false
    }
}
