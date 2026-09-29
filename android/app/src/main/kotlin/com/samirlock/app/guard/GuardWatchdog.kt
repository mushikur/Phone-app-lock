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

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        runCatching { alarmManager.cancel(pendingIntent(context)) }
        GuardLog.d("watchdog: cancelled")
    }

    private fun pendingIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        Intent(context, GuardWatchdogReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
