package com.samirlock.app.permissions

import android.Manifest
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings

/**
 * Identifiers shared with the Flutter layer. Keep in sync with `AppPermission`
 * on the Dart side.
 */
internal object PermissionIds {
    const val USAGE_ACCESS = "usageAccess"
    const val DISPLAY_OVER_OTHER_APPS = "displayOverOtherApps"
    const val NOTIFICATIONS = "notifications"
    const val BATTERY_OPTIMIZATION = "batteryOptimization"

    val all = listOf(
        USAGE_ACCESS,
        DISPLAY_OVER_OTHER_APPS,
        NOTIFICATIONS,
        BATTERY_OPTIMIZATION,
    )
}

/** Status values shared with the Flutter layer. */
internal object PermissionStatuses {
    const val GRANTED = "granted"
    const val DENIED = "denied"

    /** Nothing to grant on this Android version. */
    const val UNSUPPORTED = "unsupported"
}

/**
 * Reads the current state of every permission Samir Lock asks for.
 *
 * All checks are read-only and side-effect free, so the Flutter layer can call
 * this freely — in particular every time the app resumes from Settings.
 */
class PermissionChecker(context: Context) {

    private val appContext = context.applicationContext

    /** Current status of every known permission, keyed by its shared identifier. */
    fun snapshot(): Map<String, String> =
        PermissionIds.all.associateWith { status(it) }

    fun status(permissionId: String): String = when (permissionId) {
        PermissionIds.USAGE_ACCESS -> usageAccessStatus()
        PermissionIds.DISPLAY_OVER_OTHER_APPS -> overlayStatus()
        PermissionIds.NOTIFICATIONS -> notificationStatus()
        PermissionIds.BATTERY_OPTIMIZATION -> batteryOptimizationStatus()
        else -> PermissionStatuses.UNSUPPORTED
    }

    /**
     * Usage Access is an AppOps grant rather than a runtime permission, so it is
     * read through [AppOpsManager]. MODE_DEFAULT means "defer to the manifest
     * permission", which is the case on some OEM builds.
     */
    private fun usageAccessStatus(): String {
        val appOps = appContext.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return PermissionStatuses.DENIED

        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                appContext.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                appContext.packageName,
            )
        }

        val granted = when (mode) {
            AppOpsManager.MODE_ALLOWED -> true
            AppOpsManager.MODE_DEFAULT -> appContext.checkCallingOrSelfPermission(
                Manifest.permission.PACKAGE_USAGE_STATS,
            ) == PackageManager.PERMISSION_GRANTED

            else -> false
        }

        return granted.asStatus()
    }

    private fun overlayStatus(): String =
        Settings.canDrawOverlays(appContext).asStatus()

    /**
     * POST_NOTIFICATIONS only exists on API 33+. On older versions the user can
     * still switch notifications off in Settings, so the effective state is read
     * from the notification manager instead.
     */
    private fun notificationStatus(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = appContext.checkSelfPermission(
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            return granted.asStatus()
        }

        val manager =
            appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return PermissionStatuses.UNSUPPORTED
        return manager.areNotificationsEnabled().asStatus()
    }

    private fun batteryOptimizationStatus(): String {
        val powerManager = appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return PermissionStatuses.UNSUPPORTED
        return powerManager.isIgnoringBatteryOptimizations(appContext.packageName).asStatus()
    }

    /** True when the POST_NOTIFICATIONS runtime prompt exists on this device. */
    fun canRequestNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU

    private fun Boolean.asStatus(): String =
        if (this) PermissionStatuses.GRANTED else PermissionStatuses.DENIED
}
