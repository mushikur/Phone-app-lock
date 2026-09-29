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
        startPolling()

        // Android may restart the service after reclaiming memory; protection is
        // meant to keep working, so let it come back.
        return START_STICKY
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

        val lockedPackages = lockedAppsStore.lockedPackages()
        val foregroundPackage = detector.currentForegroundPackage() ?: return

        if (lockedPackages.isEmpty()) return

        val decision = LockCoordinator.onForegroundPackage(
            packageName = foregroundPackage,
            lockedPackages = lockedPackages,
            selfPackage = packageName,
            nowMs = System.currentTimeMillis(),
        )

        if (decision is LockCoordinator.Decision.ShowLock) {
            GuardLog.d("service: locking ${decision.packageName} (${decision.reason})")
            showLockScreen(decision.packageName)
        }
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

        /** Whether the service is currently up, for reporting status to Flutter. */
        @Volatile
        var isRunning: Boolean = false
            private set
    }
}
