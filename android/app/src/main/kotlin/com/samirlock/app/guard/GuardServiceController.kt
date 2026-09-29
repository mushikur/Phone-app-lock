package com.samirlock.app.guard

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
        return checker.status(PermissionIds.USAGE_ACCESS) == PermissionStatuses.GRANTED &&
            checker.status(PermissionIds.DISPLAY_OVER_OTHER_APPS) == PermissionStatuses.GRANTED
    }

    fun isRunning(): Boolean = GuardService.isRunning

    /** @return true when the service was started. */
    fun start(context: Context): Boolean {
        if (!canRun(context)) return false

        val intent = Intent(context, GuardService::class.java)
        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }.isSuccess
    }

    fun stop(context: Context) {
        LockCoordinator.reset()
        runCatching { context.stopService(Intent(context, GuardService::class.java)) }
    }
}
