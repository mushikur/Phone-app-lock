package com.samirlock.app.notifications

import android.content.Context
import com.samirlock.app.data.LockedAppsStore
import com.samirlock.app.guard.GuardPreferences

/**
 * Why notification hiding is, or is not, doing anything right now.
 *
 * Hiding has four preconditions, and until now every one of them failed in
 * silence: the switch could be on, the service bound, and nothing would happen
 * because protection was off or no app was locked. This turns that into
 * something the app can state plainly.
 */
object NotificationPrivacyState {

    /** Reasons hiding is inactive, in the order the user should address them. */
    enum class Blocker(val wireName: String) {
        /** Nothing is blocking it; hiding is active. */
        NONE("none"),

        /** Android notification access has not been granted. */
        NO_ACCESS("noAccess"),

        /** The user has not switched the feature on. */
        DISABLED("off"),

        /** App protection is off, so no app is locked to hide anything for. */
        PROTECTION_OFF("protectionOff"),

        /** The feature is on but no apps have been chosen to lock. */
        NO_LOCKED_APPS("noLockedApps"),
    }

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
}
