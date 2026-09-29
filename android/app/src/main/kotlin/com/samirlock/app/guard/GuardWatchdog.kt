package com.samirlock.app.guard

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.SystemClock

/**
 * A periodic nudge that puts the guard back up if it has gone away.
 *
 * Deliberately modest: an inexact repeating alarm, which needs no permission and
 * which Android is free to batch with other work and defer in Doze. It is a
 * safety net for a process the system decided to reclaim, not a mechanism for
 * keeping the app alive against the platform's wishes.
 */
object GuardWatchdog {

    private const val REQUEST_CODE = 4803
    private const val RETRY_REQUEST_CODE = 4804

    /** Long enough that the alarm is cheap, short enough to notice a kill. */
    private val INTERVAL_MS = AlarmManager.INTERVAL_FIFTEEN_MINUTES

    fun schedule(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val firstTrigger = SystemClock.elapsedRealtime() + INTERVAL_MS

        runCatching {
            alarmManager.setInexactRepeating(
                AlarmManager.ELAPSED_REALTIME,
                firstTrigger,
                INTERVAL_MS,
                pendingIntent(context),
            )
        }
            .onSuccess { GuardLog.d("watchdog: scheduled every ${INTERVAL_MS / 60_000}min") }
            .onFailure { GuardLog.w("watchdog: could not schedule", it) }
    }

    /**
     * A one-off nudge a little way out.
     *
     * Boot is the busiest moment on the device and a start can be refused for
     * reasons that have gone away seconds later; without this the next chance
     * would be a quarter of an hour away.
     */
    fun scheduleRetry(context: Context, delayMs: Long) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        runCatching {
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + delayMs,
                retryPendingIntent(context),
            )
        }
            .onSuccess { GuardLog.d("watchdog: retry scheduled in ${delayMs / 1000}s") }
            .onFailure { GuardLog.w("watchdog: could not schedule retry", it) }
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        runCatching { alarmManager.cancel(pendingIntent(context)) }
        runCatching { alarmManager.cancel(retryPendingIntent(context)) }
        GuardLog.d("watchdog: cancelled")
    }

    private fun pendingIntent(context: Context): PendingIntent =
        broadcastTo(context, REQUEST_CODE)

    private fun retryPendingIntent(context: Context): PendingIntent =
        broadcastTo(context, RETRY_REQUEST_CODE)

    private fun broadcastTo(context: Context, requestCode: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(context, GuardWatchdogReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}
