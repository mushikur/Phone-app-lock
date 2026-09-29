package com.samirlock.app.guard

import android.app.ForegroundServiceStartNotAllowedException
import android.content.Context
import android.content.Intent
import android.os.Build
import com.samirlock.app.permissions.PermissionChecker
import com.samirlock.app.permissions.PermissionIds
import com.samirlock.app.permissions.PermissionStatuses

/**
 * Starts and stops [GuardService], and reports whether it is allowed to run.
 *
 * Protection is only started when the permissions it depends on are in place, so
 * the service never comes up just to immediately stop itself.
 */
object GuardServiceController {

    /**
     * True when the permissions protection depends on are granted.
     *
     * Usage access is what makes detection possible; the overlay grant is what
     * allows the lock screen to be shown from the background.
     */
    fun canRun(context: Context): Boolean {
        val checker = PermissionChecker(context)
        val usageAccess = checker.status(PermissionIds.USAGE_ACCESS)
        val overlay = checker.status(PermissionIds.DISPLAY_OVER_OTHER_APPS)
        val canRun = usageAccess == PermissionStatuses.GRANTED &&
            overlay == PermissionStatuses.GRANTED
        if (!canRun) {
            GuardLog.configure(context)
            GuardLog.w("controller: cannot run, usageAccess=$usageAccess overlay=$overlay")
        }
        return canRun
    }

    fun isRunning(): Boolean = GuardService.isRunning

    /** @return true when the service was started. */
    fun start(context: Context): Boolean {
        GuardLog.configure(context)
        if (!canRun(context)) return false

        GuardLog.d("controller: starting guard service")
        val intent = Intent(context, GuardService::class.java)

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        } catch (error: Exception) {
            // Android 12+ refuses foreground service starts from the background.
            // Samir Lock is normally exempt because it holds the overlay
            // permission, so this mostly means that permission has gone — worth
            // naming rather than swallowing.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                error is ForegroundServiceStartNotAllowedException
            ) {
                GuardLog.w("controller: not allowed to start the guard from the background", error)
            } else {
                GuardLog.w("controller: could not start the guard", error)
            }
            false
        }
    }

    /**
     * Brings the guard back up when the user has protection switched on but the
     * service is not running.
     *
     * The stored flag is the user's intent; it survives the process being killed,
     * an app update, or Android reclaiming memory, while the service does not.
     * Without this, protection reads as "on" in the UI while nothing is actually
     * watching. Called when the app starts and whenever its status is read.
     *
     * @return true when the guard is running, or was just started.
     */
    fun startIfEnabled(context: Context): Boolean {
        if (!GuardPreferences(context).isProtectionEnabled) return false
        if (isRunning()) return true

        GuardLog.configure(context)
        GuardLog.d("controller: protection is on but the guard is not running, restarting")
        return start(context)
    }

    fun stop(context: Context) {
        GuardLog.configure(context)
        GuardLog.d("controller: stopping guard service")
        GuardWatchdog.cancel(context)
        LockCoordinator.reset()
        runCatching { context.stopService(Intent(context, GuardService::class.java)) }
    }
}
