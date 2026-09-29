package com.samirlock.app.notifications

import android.app.NotificationManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.samirlock.app.data.LockedAppsStore
import com.samirlock.app.guard.GuardLog
import com.samirlock.app.guard.GuardPreferences
import com.samirlock.app.guard.LockCoordinator

/**
 * Hides what notifications from locked apps say, while they are still locked.
 *
 * Android gives no way to redact another app's notification in place, so the
 * only way to hide the content is to take the notification down and put a
 * stand-in of our own in its place. The stand-in keeps the original's tap
 * action, so opening it still goes to the right app — and the lock screen then
 * asks for the PIN.
 *
 * The trade-off is real and worth being clear about: the original notification
 * is gone, not stored. What the user sees after unlocking is whatever the app
 * itself shows. Nothing about the hidden notification is written anywhere.
 */
class NotificationPrivacyService : NotificationListenerService() {

    private lateinit var preferences: GuardPreferences
    private lateinit var lockedAppsStore: LockedAppsStore

    /** How many notifications are currently hidden per package. */
    private val hiddenCounts = mutableMapOf<String, Int>()

    override fun onCreate() {
        super.onCreate()
        GuardLog.configure(this)
        preferences = GuardPreferences(this)
        lockedAppsStore = LockedAppsStore(this)
        NotificationPrivacy.ensureChannel(this)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        GuardLog.d("privacy: listener connected")
    }

    override fun onListenerDisconnected() {
        instance = null
        hiddenCounts.clear()
        GuardLog.d("privacy: listener disconnected")
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn ?: return
        if (!shouldHide(notification)) return

        val packageName = notification.packageName
        val count = (hiddenCounts[packageName] ?: 0) + 1
        hiddenCounts[packageName] = count

        // Take the original down first, so its content is never left on screen.
        runCatching { cancelNotification(notification.key) }
            .onFailure {
                GuardLog.w("privacy: could not take down a notification", it)
                hiddenCounts[packageName] = count - 1
                return
            }

        val placeholder = NotificationPrivacy.buildPlaceholder(
            context = this,
            appName = appLabel(packageName),
            count = count,
            originalIntent = notification.notification?.contentIntent,
        )

        val manager = getSystemService(NotificationManager::class.java)
        runCatching {
            manager?.notify(NotificationPrivacy.notificationIdFor(packageName), placeholder)
        }.onFailure { GuardLog.w("privacy: could not post the stand-in", it) }

        // Deliberately logs the package only. What the notification said is
        // never read into a log, a file or anywhere else.
        GuardLog.d("privacy: hid a notification from $packageName (now $count)")
    }

    /**
     * Only notifications from an app that is locked right now, and only when the
     * user asked for this.
     */
    private fun shouldHide(sbn: StatusBarNotification): Boolean {
        if (!preferences.isNotificationPrivacyEnabled) return false
        if (!preferences.isProtectionEnabled) return false

        val packageName = sbn.packageName ?: return false
        if (packageName == this.packageName) return false
        if (packageName !in lockedAppsStore.lockedPackages()) return false

        // An app the user has just unlocked is not hidden; they are looking at it.
        if (LockCoordinator.isUnlocked(packageName)) return false

        // Ongoing notifications are things like a music player or a call. Taking
        // those down would break the app rather than protect the user.
        if (sbn.isOngoing) return false
        if (!sbn.isClearable) return false

        return true
    }

    private fun appLabel(packageName: String): String = runCatching {
        val info = packageManager.getApplicationInfo(packageName, 0)
        packageManager.getApplicationLabel(info).toString()
    }.getOrDefault(packageName)

    companion object {
        @Volatile
        private var instance: NotificationPrivacyService? = null

        /**
         * Clears the stand-in for an app the user has just unlocked.
         *
         * Called from the lock screen after a successful authentication.
         */
        fun onPackageUnlocked(packageName: String) {
            val service = instance ?: return
            service.hiddenCounts.remove(packageName)
            NotificationPrivacy.cancelPlaceholder(service, packageName)
        }
    }
}
