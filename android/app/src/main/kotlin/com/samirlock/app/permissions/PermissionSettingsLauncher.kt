package com.samirlock.app.permissions

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings

/**
 * Opens the correct Android Settings page for each permission.
 *
 * Every permission has an ordered list of candidate intents: the page that lands
 * directly on Samir Lock's entry first, then the generic page, then a safe
 * fallback. OEM builds routinely omit the deep-linked variants, so each
 * candidate is checked against the package manager before it is launched and
 * [open] reports back instead of throwing when none of them resolve.
 */
class PermissionSettingsLauncher(context: Context) {

    private val appContext = context.applicationContext

    /**
     * Launches the settings page for [permissionId], preferring [activity] as the
     * launch context so the page appears inside the app's own task.
     *
     * @return true when a settings page was opened.
     */
    fun open(permissionId: String, activity: Activity?): Boolean {
        val launcher: Context = activity ?: appContext
        val candidates = candidatesFor(permissionId)

        for (intent in candidates) {
            if (activity == null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(appContext.packageManager) == null) continue

            val launched = runCatching { launcher.startActivity(intent) }.isSuccess
            if (launched) return true
        }

        return false
    }

    private fun candidatesFor(permissionId: String): List<Intent> = when (permissionId) {
        PermissionIds.USAGE_ACCESS -> listOf(
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, packageUri()),
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )

        PermissionIds.DISPLAY_OVER_OTHER_APPS -> listOf(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, packageUri()),
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION),
            appDetailsIntent(),
        )

        PermissionIds.NOTIFICATIONS -> listOf(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, appContext.packageName),
            appDetailsIntent(),
        )

        // The system list of battery-optimised apps. Deliberately not
        // ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: that needs an extra
        // permission and pushes a dialog at the user, and this setting is only a
        // recommendation.
        PermissionIds.BATTERY_OPTIMIZATION -> listOf(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            appDetailsIntent(),
        )

        else -> emptyList()
    }

    private fun appDetailsIntent(): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri())

    private fun packageUri(): Uri = Uri.fromParts("package", appContext.packageName, null)
}
