package com.samirlock.app.notifications

import android.content.Context
import com.samirlock.app.data.LockedAppsStore
import com.samirlock.app.guard.GuardPreferences
import java.util.concurrent.atomic.AtomicInteger

/**
 * Why notification hiding is, or is not, doing anything right now.
 *
 * Hiding has four preconditions and several per-notification reasons to leave
 * one alone, and every one of them used to fail in silence: the switch could be
 * on, the service bound, and nothing would happen. Release builds log nothing,
 * so without this there is no way to tell which. These counters are what the
 * settings screen reports, and they hold nothing but counts and reason codes —
 * never a package's notification content.
 */
object NotificationPrivacyState {

    /** Reasons hiding is inactive overall, in the order the user should act on. */
    enum class Blocker(val wireName: String) {
        NONE("none"),
        NO_ACCESS("noAccess"),
        DISABLED("off"),
        PROTECTION_OFF("protectionOff"),
        NO_LOCKED_APPS("noLockedApps"),
    }

    /** Why a particular notification was left alone. */
    enum class Skip(val wireName: String) {
        NOT_ACTIVE("notActive"),
        OWN_APP("ownApp"),
        NOT_LOCKED("notLocked"),
        ALREADY_UNLOCKED("alreadyUnlocked"),
        ONGOING("ongoing"),
    }

    private val seen = AtomicInteger(0)
    private val hidden = AtomicInteger(0)
    private val cancelFailures = AtomicInteger(0)

    @Volatile
    private var lastSkip: Skip? = null

    fun recordSeen() = seen.incrementAndGet()

    fun recordHidden(count: Int) = hidden.addAndGet(count)

    fun recordSkipped(skip: Skip) {
        lastSkip = skip
    }

    fun recordCancelFailed() = cancelFailures.incrementAndGet()

    fun blocker(context: Context): Blocker {
        val preferences = GuardPreferences(context)

        if (!NotificationPrivacy.hasAccess(context)) return Blocker.NO_ACCESS
        if (!preferences.isNotificationPrivacyEnabled) return Blocker.DISABLED
        if (!preferences.isProtectionEnabled) return Blocker.PROTECTION_OFF
        if (LockedAppsStore(context).lockedPackages().isEmpty()) {
            return Blocker.NO_LOCKED_APPS
        }
        return Blocker.NONE
    }

    fun isActive(context: Context): Boolean = blocker(context) == Blocker.NONE

    /**
     * The same question, minus the notification-access check, for use inside the
     * listener itself.
     *
     * Reading that setting means a ContentResolver call, and it sits in front of
     * every cancellation. It is also redundant there: the listener only receives
     * a callback at all while it is connected, and it is only connected while
     * access is granted. The remaining checks are in-memory preference reads.
     */
    fun isActiveForListener(context: Context): Boolean {
        val preferences = GuardPreferences(context)
        if (!preferences.isNotificationPrivacyEnabled) return false
        if (!preferences.isProtectionEnabled) return false
        return LockedAppsStore(context).lockedPackages().isNotEmpty()
    }

    /** Counts and reason codes for the settings screen. Never any content. */
    fun diagnostics(): Map<String, Any?> = mapOf(
        "seen" to seen.get(),
        "hidden" to hidden.get(),
        "cancelFailures" to cancelFailures.get(),
        "lastSkip" to (lastSkip?.wireName ?: ""),
    )
}
