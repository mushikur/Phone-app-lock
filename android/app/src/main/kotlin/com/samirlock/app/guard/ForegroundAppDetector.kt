package com.samirlock.app.guard

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build

/**
 * Reports which app is currently in the foreground, using usage events.
 *
 * Each call reads only the events that arrived since the previous one, so a poll
 * costs a handful of events rather than a rescan of recent history. The last
 * resumed package is remembered, which means "nothing changed" is answered
 * without any further work.
 */
class ForegroundAppDetector(context: Context) {

    private val usageStatsManager =
        context.applicationContext.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager

    private var lastEventTimeMs = 0L
    private var lastKnownPackage: String? = null

    /** Polls with no usable result, for spotting a silently failing query. */
    private var emptyReads = 0

    /**
     * The package of the app in the foreground, or null when it is not yet known
     * (no resume event has been seen and none is in the recent window).
     */
    fun currentForegroundPackage(nowMs: Long = System.currentTimeMillis()): String? {
        val manager = usageStatsManager
        if (manager == null) {
            GuardLog.w("detector: UsageStatsManager unavailable")
            return null
        }

        // First read looks back far enough to find the app already on screen;
        // later reads only take what is new.
        val begin = if (lastEventTimeMs == 0L) nowMs - INITIAL_LOOKBACK_MS else lastEventTimeMs + 1
        if (begin > nowMs) return lastKnownPackage

        val events = runCatching { manager.queryEvents(begin, nowMs) }
            .onFailure { GuardLog.w("detector: queryEvents failed", it) }
            .getOrNull()
            ?: return lastKnownPackage

        var resumeEvents = 0
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType != resumedEventType) continue

            val packageName = event.packageName ?: continue
            resumeEvents++
            if (packageName != lastKnownPackage) {
                GuardLog.d("detector: foreground -> $packageName")
            }
            lastKnownPackage = packageName
            lastEventTimeMs = event.timeStamp
        }

        if (resumeEvents == 0 && lastKnownPackage == null) {
            emptyReads++
            // Loud enough to notice, rare enough not to flood: a run of these means
            // usage access is not really working, whatever the permission says.
            if (emptyReads % EMPTY_READ_LOG_EVERY == 0) {
                GuardLog.w(
                    "detector: $emptyReads polls with no foreground app yet " +
                        "(window ${nowMs - begin}ms) - is usage access really granted?",
                )
            }
        } else {
            emptyReads = 0
        }

        return lastKnownPackage
    }

    /** Forgets the cached foreground app, for instance after the screen goes off. */
    fun reset() {
        lastEventTimeMs = 0L
        lastKnownPackage = null
        emptyReads = 0
        GuardLog.d("detector: reset")
    }

    private val resumedEventType: Int
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            UsageEvents.Event.ACTIVITY_RESUMED
        } else {
            @Suppress("DEPRECATION")
            UsageEvents.Event.MOVE_TO_FOREGROUND
        }

    private companion object {
        const val INITIAL_LOOKBACK_MS = 10_000L
        const val EMPTY_READ_LOG_EVERY = 30
    }
}
