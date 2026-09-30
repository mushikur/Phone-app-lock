package com.samirlock.app.notifications

import android.app.NotificationManager
import android.app.PendingIntent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.samirlock.app.data.LockedAppsStore
import com.samirlock.app.guard.GuardLog
import com.samirlock.app.guard.LockCoordinator
import java.util.concurrent.ConcurrentHashMap

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
 * itself shows. Nothing about the hidden notification is written anywhere, and
 * nothing from it is ever copied into the stand-in.
 */
class NotificationPrivacyService : NotificationListenerService() {

    private lateinit var lockedAppsStore: LockedAppsStore

    /**
     * The notification keys currently hidden, per package.
     *
     * Keys rather than a running total: apps re-post a notification whenever
     * they update it, and counting every re-post would have the stand-in
     * claiming five new messages when one arrived five times.
     */
    private val hiddenKeys = ConcurrentHashMap<String, MutableSet<String>>()

    override fun onCreate() {
        super.onCreate()
        GuardLog.configure(this)
        lockedAppsStore = LockedAppsStore(this)
        NotificationPrivacy.ensureChannel(this)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        GuardLog.d("privacy: listener connected")

        // Notifications that arrived before this connection are already on
        // screen showing their content. Without this sweep they stay visible
        // for as long as the user leaves them there — which is exactly what a
        // service that restarts after a reboot or an update would leave behind.
        sweepLockedPackages()
    }

    override fun onListenerDisconnected() {
        instance = null
        hiddenKeys.clear()
        GuardLog.d("privacy: listener disconnected")
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    /**
     * The two-argument form is the one the platform actually calls; the
     * single-argument form only exists because the default implementation of
     * this one forwards to it. Overriding this directly removes that hop and
     * any chance of an OEM framework skipping it.
     */
    override fun onNotificationPosted(sbn: StatusBarNotification?, rankingMap: RankingMap?) {
        val notification = sbn ?: return
        NotificationPrivacyState.recordSeen()

        val skip = skipReason(notification)
        if (skip != null) {
            NotificationPrivacyState.recordSkipped(skip)
            return
        }

        hide(notification.packageName, notification.key, notification.notification?.contentIntent)
    }

    /**
     * Takes down everything this package currently has on screen, not just the
     * one notification that triggered this.
     *
     * Messaging apps post a group summary alongside each message, and the
     * summary carries the same sender and text. Cancelling only the child would
     * leave the content on display in the summary, which is the whole thing this
     * feature exists to prevent.
     */
    private fun hide(packageName: String, key: String?, contentIntent: PendingIntent?) {
        val taken = mutableListOf<String>()
        var tapAction = contentIntent

        if (key != null && cancel(key)) taken += key

        for (active in activeFor(packageName)) {
            if (active.key == key) continue
            if (!isHideable(active)) continue
            if (tapAction == null) tapAction = active.notification?.contentIntent
            if (cancel(active.key)) taken += active.key
        }

        if (taken.isEmpty()) {
            // Nothing came down, so posting a stand-in would only add noise on
            // top of content that is still showing.
            NotificationPrivacyState.recordCancelFailed()
            GuardLog.w("privacy: could not take down notifications from $packageName")
            return
        }

        val keys = hiddenKeys.getOrPut(packageName) { ConcurrentHashMap.newKeySet() }
        val fresh = taken.count(keys::add)

        postPlaceholder(packageName, keys.size, tapAction)
        if (fresh > 0) NotificationPrivacyState.recordHidden(fresh)

        // The package name only. What the notification said is never logged.
        GuardLog.d("privacy: hid ${taken.size} from $packageName (${keys.size} held)")
    }

    private fun postPlaceholder(packageName: String, count: Int, tapAction: PendingIntent?) {
        val placeholder = NotificationPrivacy.buildPlaceholder(
            context = this,
            appName = appLabel(packageName),
            count = count,
            originalIntent = tapAction,
        )

        val manager = getSystemService(NotificationManager::class.java)
        runCatching {
            manager?.notify(NotificationPrivacy.notificationIdFor(packageName), placeholder)
        }.onFailure { GuardLog.w("privacy: could not post the stand-in", it) }
    }

    /** Hides anything already on screen for apps that are locked right now. */
    private fun sweepLockedPackages() {
        if (!NotificationPrivacyState.isActive(this)) return

        val locked = lockedAppsStore.lockedPackages()
        for (packageName in locked) {
            if (LockCoordinator.isUnlocked(packageName)) continue
            val active = activeFor(packageName).filter(::isHideable)
            if (active.isEmpty()) continue
            hide(packageName, null, active.first().notification?.contentIntent)
        }
    }

    private fun activeFor(packageName: String): List<StatusBarNotification> =
        runCatching { activeNotifications }
            .getOrNull()
            .orEmpty()
            .filter { it.packageName == packageName }

    private fun cancel(key: String): Boolean =
        runCatching { cancelNotification(key) }.isSuccess

    /**
     * Why this notification is being left alone, or null when it should be hidden.
     */
    private fun skipReason(sbn: StatusBarNotification): NotificationPrivacyState.Skip? {
        // Cheapest checks first. This runs for every notification on the device,
        // from every app, and the active check reads a system setting - work
        // worth doing only once a notification is a candidate.
        val packageName = sbn.packageName ?: return NotificationPrivacyState.Skip.NOT_ACTIVE
        if (packageName == this.packageName) return NotificationPrivacyState.Skip.OWN_APP

        // Ongoing notifications are things like a music player or a call. Taking
        // those down would break the app rather than protect the user.
        if (!isHideable(sbn)) return NotificationPrivacyState.Skip.ONGOING

        if (packageName !in lockedAppsStore.lockedPackages()) {
            return NotificationPrivacyState.Skip.NOT_LOCKED
        }

        // An app the user has just unlocked is not hidden; they are looking at it.
        if (LockCoordinator.isUnlocked(packageName)) {
            return NotificationPrivacyState.Skip.ALREADY_UNLOCKED
        }

        // One source of truth with the settings screen: whatever it tells the
        // user is blocking hiding is exactly what is checked here.
        if (!NotificationPrivacyState.isActive(this)) {
            return NotificationPrivacyState.Skip.NOT_ACTIVE
        }

        return null
    }

    private fun isHideable(sbn: StatusBarNotification): Boolean =
        !sbn.isOngoing && sbn.isClearable

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
            service.hiddenKeys.remove(packageName)
            NotificationPrivacy.cancelPlaceholder(service, packageName)
        }
    }
}
