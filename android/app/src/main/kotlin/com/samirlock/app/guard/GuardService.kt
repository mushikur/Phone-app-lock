package com.samirlock.app.guard

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import com.samirlock.app.data.LockedAppsStore
import com.samirlock.app.lock.LockActivity
import com.samirlock.app.permissions.PermissionChecker
import com.samirlock.app.permissions.PermissionIds
import com.samirlock.app.permissions.PermissionStatuses

/**
 * Watches which app is in the foreground and shows the lock screen when a locked
 * app is opened.
 *
 * Runs as a foreground service because the work has to continue while the user is
 * in other apps. Polling only happens while the screen is on: the receiver below
 * stops the loop on screen-off and restarts it on screen-on, which is where most
 * of the battery saving comes from.
 */
class GuardService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var detector: ForegroundAppDetector
    private lateinit var lockedAppsStore: LockedAppsStore
    private lateinit var permissionChecker: PermissionChecker

    private var isPolling = false
    private var ticks = 0L

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isPolling) return
            tick()
            if (isPolling) handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    GuardLog.d("service: screen off")
                    stopPolling()
                    // Everything relocks: the user has to unlock again after the
                    // screen comes back.
                    LockCoordinator.onScreenOff()
                    detector.reset()
                }

                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> {
                    GuardLog.d("service: ${intent.action?.substringAfterLast('.')}")
                    startPolling()
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        GuardLog.configure(this)
        detector = ForegroundAppDetector(this)
        lockedAppsStore = LockedAppsStore(this)
        permissionChecker = PermissionChecker(this)

        GuardNotifications.ensureChannel(this)
        registerScreenReceiver()
        GuardLog.d("service: created")
    }

    /**
     * These are system broadcasts, so Android 14's export requirement technically
     * exempts them — declaring NOT_EXPORTED anyway keeps the intent explicit and
     * leaves no room for a SecurityException on a future target SDK.
     */
    private fun registerScreenReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()

        val usageAccess = permissionChecker.status(PermissionIds.USAGE_ACCESS)
        val overlay = permissionChecker.status(PermissionIds.DISPLAY_OVER_OTHER_APPS)
        GuardLog.d(
            "service: onStartCommand restart=${intent == null} " +
                "usageAccess=$usageAccess overlay=$overlay " +
                "locked=${lockedAppsStore.lockedPackages()}",
        )

        // Usage access can be revoked while the service is running, and without it
        // there is nothing to watch.
        if (usageAccess != PermissionStatuses.GRANTED) {
            GuardLog.w("service: stopping, usage access not granted")
            stopSelf()
            return START_NOT_STICKY
        }

        isRunning = true
        GuardWatchdog.schedule(this)

        // Starting while the screen is off would poll into a dark screen until the
        // user picked the phone up; the screen-on broadcast starts the loop then.
        if (isScreenInteractive()) {
            startPolling()
        } else {
            GuardLog.d("service: screen is off, waiting for it to come on")
        }

        // Android may restart the service after reclaiming memory; protection is
        // meant to keep working, so let it come back.
        return START_STICKY
    }

    /**
     * Swiping Samir Lock out of Recents must not take protection down with it.
     *
     * The guard runs independently of that task, so there is nothing to restart
     * here; what matters is that the safety net is armed in case the system
     * reclaims the process afterwards.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        GuardLog.d("service: task removed, protection stays up")
        GuardWatchdog.schedule(this)
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        GuardLog.d("service: destroyed after $ticks polls")
        stopPolling()
        isRunning = false
        runCatching { unregisterReceiver(screenReceiver) }
        LockCoordinator.reset()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * Declares the service as `specialUse`, which is the foreground service type
     * Android 14 and newer require for app locking.
     */
    private fun startAsForeground() {
        val notification = GuardNotifications.build(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                GuardNotifications.NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(GuardNotifications.NOTIFICATION_ID, notification)
        }
    }

    private fun isScreenInteractive(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
        return power.isInteractive
    }

    private fun startPolling() {
        if (isPolling) return
        isPolling = true
        handler.post(pollRunnable)
        GuardLog.d("service: polling started (every ${POLL_INTERVAL_MS}ms)")
    }

    private fun stopPolling() {
        if (!isPolling) return
        isPolling = false
        handler.removeCallbacks(pollRunnable)
        GuardLog.d("service: polling stopped")
    }

    private fun tick() {
        ticks++

        // Usage access can be taken away at any time, and the poll would then
        // silently return nothing forever; re-checking occasionally turns that
        // into a clear stop instead of a mystery.
        if (ticks % USAGE_ACCESS_RECHECK_TICKS == 0L &&
            permissionChecker.status(PermissionIds.USAGE_ACCESS) != PermissionStatuses.GRANTED
        ) {
            GuardLog.w("service: usage access revoked, stopping")
            stopSelf()
            return
        }

        // Check this before querying usage events: with nothing locked there is
        // no reason to do the expensive part of the poll at all.
        val lockedPackages = lockedAppsStore.lockedPackages()
        if (lockedPackages.isEmpty()) return

        val foregroundPackage = detector.currentForegroundPackage() ?: return

        val decision = LockCoordinator.onForegroundPackage(
            packageName = foregroundPackage,
            lockedPackages = lockedPackages,
            selfPackage = packageName,
            nowMs = System.currentTimeMillis(),
        )

        if (decision is LockCoordinator.Decision.ShowLock) {
            GuardLog.d("service: locking ${decision.packageName} (${decision.reason})")
            showLockScreen(decision.packageName)
            checkLaunchesAreLanding()
        }
    }

    /**
     * Notices when lock screens are being asked for but never appear.
     *
     * Starting an activity from the background throws nothing when it is refused —
     * the lock simply does not show — and the only reason Samir Lock is allowed to
     * do it at all is the overlay permission. If that has been taken away, the
     * honest response is to stop, so the app reports that it cannot protect
     * anything instead of quietly protecting nothing.
     */
    private fun checkLaunchesAreLanding() {
        if (LockCoordinator.unconfirmedLaunchCount() < UNCONFIRMED_LAUNCH_LIMIT) return

        val overlay = permissionChecker.status(PermissionIds.DISPLAY_OVER_OTHER_APPS)
        if (overlay == PermissionStatuses.GRANTED) {
            GuardLog.w(
                "service: ${LockCoordinator.unconfirmedLaunchCount()} lock launches " +
                    "did not appear, but the overlay permission is granted; retrying",
            )
            return
        }

        GuardLog.w("service: lock screens cannot be shown (overlay=$overlay), stopping")
        stopSelf()
    }

    /**
     * Starting an activity from the background is only allowed because the user
     * granted "display over other apps"; that grant is what makes the lock screen
     * possible at all.
     */
    private fun showLockScreen(lockedPackage: String) {
        val intent = LockActivity.intentFor(this, lockedPackage).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
            )
        }
        runCatching { startActivity(intent) }
            .onSuccess { GuardLog.d("service: startActivity issued for $lockedPackage") }
            .onFailure {
                GuardLog.w("service: startActivity failed for $lockedPackage", it)
                LockCoordinator.onLockClosed(lockedPackage)
            }
    }

    companion object {
        /**
         * How often the foreground app is checked while the screen is on.
         *
         * Usage events are only written by the system every so often, so polling
         * faster than this buys latency that the platform cannot actually deliver
         * while costing measurably more battery.
         */
        private const val POLL_INTERVAL_MS = 350L

        /** Roughly every 20 seconds at the poll interval above. */
        private const val USAGE_ACCESS_RECHECK_TICKS = 60L

        /** Lock launches that may go unconfirmed before the cause is investigated. */
        private const val UNCONFIRMED_LAUNCH_LIMIT = 3

        /** Whether the service is currently up, for reporting status to Flutter. */
        @Volatile
        var isRunning: Boolean = false
            private set
    }
}
