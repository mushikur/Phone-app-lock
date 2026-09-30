package com.samirlock.app.notifications

import android.app.NotificationManager
import android.app.PendingIntent
import android.os.Handler
import android.os.Looper
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
 * itself shows. Nothing from the original is ever copied into the stand-in.
 */
class NotificationPrivacyService : NotificationListenerService() {

    private lateinit var lockedAppsStore: LockedAppsStore
    private val handler = Handler(Looper.getMainLooper())

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
        GuardLog.configure(this)
        GuardLog.d("privacy: listener connected")

        // Notifications that arrived before this connection are already on
        // screen showing their content. Without this sweep they stay visible
        // for as long as the user leaves them there.
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
     * this one forwards to it.
     */
    override fun onNotificationPosted(sbn: StatusBarNotification?, rankingMap: RankingMap?) {
        val notification = sbn ?: return
        NotificationPrivacyState.recordSeen()

        val skip = skipReason(notification)
        if (skip != null) {
            NotificationPrivacyState.recordSkipped(skip)
            // Only interesting for a locked app; everything else is noise.
            if (skip != NotificationPrivacyState.Skip.NOT_LOCKED &&
                skip != NotificationPrivacyState.Skip.OWN_APP
            ) {
                GuardLog.d("privacy: skipped ${notification.packageName} (${skip.wireName})")
            }
            return
        }

        GuardLog.d(
            "privacy: posted pkg=${notification.packageName} key=${notification.key} " +
                "group=${notification.notification?.group} " +
                "isGroupSummary=${isGroupSummary(notification)} " +
                "ongoing=${notification.isOngoing} clearable=${notification.isClearable}",
        )

        hide(notification.packageName, notification.key, notification.notification?.contentIntent)
    }

    /**
     * Reports what the system did with a notification, and why.
     *
     * This is how a cancel that quietly did nothing can be told apart from one
     * that worked and was undone by the app posting again: the reason code says
     * which.
     */
    override fun onNotificationRemoved(
        sbn: StatusBarNotification?,
        rankingMap: RankingMap?,
        reason: Int,
    ) {
        super.onNotificationRemoved(sbn, rankingMap, reason)
        val notification = sbn ?: return
        if (notification.packageName !in lockedAppsStore.lockedPackages()) return

        GuardLog.d(
            "privacy: removed pkg=${notification.packageName} key=${notification.key} " +
                "reason=$reason (${removalReason(reason)})",
        )
    }

    /**
     * Takes down everything this package currently has on screen, not just the
     * one notification that triggered this.
     *
     * Messaging apps post a group summary alongside each message, and the
     * summary carries the same sender and text. Cancelling only the child would
     * leave the content on display in the summary.
     */
    private fun hide(packageName: String, key: String?, contentIntent: PendingIntent?) {
        val attempted = mutableListOf<String>()
        var tapAction = contentIntent

        if (key != null) {
            cancel(key)
            attempted += key
        }

        for (active in activeFor(packageName)) {
            if (active.key == key) continue
            if (!isHideable(active)) continue
            if (tapAction == null) tapAction = active.notification?.contentIntent
            cancel(active.key)
            attempted += active.key
        }

        GuardLog.d("privacy: asked to cancel ${attempted.size} from $packageName")

        val keys = hiddenKeys.getOrPut(packageName) { ConcurrentHashMap.newKeySet() }
        val fresh = attempted.count(keys::add)

        postPlaceholder(packageName, keys.size, tapAction)
        if (fresh > 0) NotificationPrivacyState.recordHidden(fresh)

        // cancelNotification returns nothing and does not throw when it has no
        // effect, so whether it worked can only be learned by looking again.
        verifyCancelled(packageName, attempted)
    }

    /**
     * Checks shortly afterwards whether the notifications really went away.
     *
     * If they are still there the cancel was a no-op or the app put them back,
     * and one more attempt is made before recording the failure. Without this
     * the app would report notifications as hidden while they sit on screen in
     * full — which is exactly the state this feature must never be in.
     */
    private fun verifyCancelled(packageName: String, attempted: List<String>) {
        if (attempted.isEmpty()) return

        handler.postDelayed({
            val stillThere = activeFor(packageName)
                .filter { it.key in attempted && isHideable(it) }

            if (stillThere.isEmpty()) {
                GuardLog.d("privacy: confirmed hidden for $packageName")
                return@postDelayed
            }

            GuardLog.w(
                "privacy: ${stillThere.size} of ${attempted.size} still showing for " +
                    "$packageName after cancel - retrying",
            )
            stillThere.forEach { cancel(it.key) }

            handler.postDelayed({
                val remaining = activeFor(packageName)
                    .filter { it.key in attempted && isHideable(it) }
                if (remaining.isEmpty()) {
                    GuardLog.d("privacy: confirmed hidden for $packageName after retry")
                    return@postDelayed
                }

                NotificationPrivacyState.recordCancelFailed()
                GuardLog.w(
                    "privacy: CANCEL NOT TAKING EFFECT for $packageName, " +
                        "${remaining.size} still showing: ${remaining.map { it.key }}",
                )
            }, VERIFY_DELAY_MS)
        }, VERIFY_DELAY_MS)
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

        for (packageName in lockedAppsStore.lockedPackages()) {
            if (LockCoordinator.isUnlocked(packageName)) continue
            val active = activeFor(packageName).filter(::isHideable)
            if (active.isEmpty()) continue
            GuardLog.d("privacy: sweeping ${active.size} already showing for $packageName")
            hide(packageName, null, active.first().notification?.contentIntent)
        }
    }

    private fun activeFor(packageName: String): List<StatusBarNotification> =
        runCatching { activeNotifications }
            .onFailure { GuardLog.w("privacy: could not read active notifications", it) }
            .getOrNull()
            .orEmpty()
            .filter { it.packageName == packageName }

    private fun cancel(key: String) {
        runCatching { cancelNotification(key) }
            .onFailure { GuardLog.w("privacy: cancelNotification threw for $key", it) }
    }

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

        if (!NotificationPrivacyState.isActive(this)) {
            return NotificationPrivacyState.Skip.NOT_ACTIVE
        }

        return null
    }

    private fun isHideable(sbn: StatusBarNotification): Boolean =
        !sbn.isOngoing && sbn.isClearable

    private fun isGroupSummary(sbn: StatusBarNotification): Boolean =
        (sbn.notification?.flags ?: 0) and android.app.Notification.FLAG_GROUP_SUMMARY != 0

    private fun removalReason(reason: Int): String = when (reason) {
        REASON_CLICK -> "click"
        REASON_CANCEL -> "app cancelled"
        REASON_CANCEL_ALL -> "app cancelled all"
        REASON_LISTENER_CANCEL -> "our cancel"
        REASON_LISTENER_CANCEL_ALL -> "our cancel all"
        REASON_APP_CANCEL -> "app cancel"
        REASON_APP_CANCEL_ALL -> "app cancel all"
        else -> "other"
    }

    private fun appLabel(packageName: String): String = runCatching {
        val info = packageManager.getApplicationInfo(packageName, 0)
        packageManager.getApplicationLabel(info).toString()
    }.getOrDefault(packageName)

    companion object {
        /** Long enough for the system to have acted, short enough to be useful. */
        private const val VERIFY_DELAY_MS = 400L

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
