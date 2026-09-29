package com.samirlock.app.guard

/**
 * Decides when the lock screen should appear.
 *
 * Deliberately free of Android imports — the current time is passed in — so the
 * rules that matter most are plain, readable Kotlin that can be reasoned about
 * and unit tested without a device. Every decision carries a [Decision.reason],
 * which is what the service logs; that is how this is diagnosed on a real phone
 * without the coordinator knowing anything about logging.
 *
 * A single instance is shared by [GuardService] and the lock screen, which live
 * in the same process. Every entry point is synchronised because the service
 * polls from its own loop while the lock screen reports in from the main thread.
 */
object LockCoordinator {

    sealed interface Decision {
        /** Why this decision was reached, for diagnostics. */
        val reason: String

        /** Nothing to do. */
        data class None(override val reason: String) : Decision

        /** Show the lock screen for [packageName]. */
        data class ShowLock(
            val packageName: String,
            override val reason: String = "locked app entered foreground",
        ) : Decision
    }

    /**
     * How long to ignore a repeat launch for the same package.
     *
     * Usage events trail the real foreground state, so without this the same app
     * would be detected again before the lock screen has reported itself visible.
     */
    private const val RELAUNCH_COOLDOWN_MS = 1_200L

    /** Packages the user has unlocked and not yet left. */
    private val unlockedPackages = mutableSetOf<String>()

    private var foregroundPackage: String? = null
    private var lockVisibleFor: String? = null
    private var lastLaunchedPackage: String? = null
    private var lastLaunchedAtMs = 0L

    /**
     * Feeds the currently foregrounded package into the state machine.
     *
     * @param packageName the app now in the foreground.
     * @param lockedPackages the user's locked apps.
     * @param selfPackage Samir Lock's own package, which is never locked.
     */
    @Synchronized
    fun onForegroundPackage(
        packageName: String,
        lockedPackages: Set<String>,
        selfPackage: String,
        nowMs: Long,
    ): Decision {
        // Our own UI and the lock screen itself are not app switches: returning
        // early keeps the protected app's unlocked state intact while the user is
        // looking at the lock screen.
        if (packageName == selfPackage) return Decision.None("own package in foreground")

        if (packageName != foregroundPackage) {
            // Leaving an app relocks it.
            foregroundPackage?.let(unlockedPackages::remove)
            foregroundPackage = packageName
        }

        if (packageName !in lockedPackages) return Decision.None("not a locked app")
        if (packageName in unlockedPackages) return Decision.None("already unlocked by user")
        if (lockVisibleFor != null) {
            return Decision.None("lock screen already showing for $lockVisibleFor")
        }
        if (packageName == lastLaunchedPackage &&
            nowMs - lastLaunchedAtMs < RELAUNCH_COOLDOWN_MS
        ) {
            return Decision.None("launched ${nowMs - lastLaunchedAtMs}ms ago, within cooldown")
        }

        lastLaunchedPackage = packageName
        lastLaunchedAtMs = nowMs
        return Decision.ShowLock(packageName)
    }

    /** The lock screen is now on screen for [packageName]. */
    @Synchronized
    fun onLockShown(packageName: String) {
        lockVisibleFor = packageName
        GuardLog.d("coordinator: lock visible for $packageName")
    }

    /** The user satisfied the lock for [packageName]. */
    @Synchronized
    fun onUnlocked(packageName: String) {
        unlockedPackages.add(packageName)
        foregroundPackage = packageName
        lockVisibleFor = null
        clearCooldown()
        GuardLog.d("coordinator: $packageName unlocked")
    }

    /**
     * The lock screen stopped being visible while the app behind it is still
     * locked — the system stopped it, or the user navigated away.
     *
     * The lock is no longer considered on screen, so if the protected app comes
     * back to the foreground the guard covers it again. The cooldown is cleared so
     * that happens immediately rather than being swallowed by the repeat guard.
     */
    @Synchronized
    fun onLockHidden(packageName: String) {
        if (lockVisibleFor == packageName) lockVisibleFor = null
        clearCooldown()
        GuardLog.d("coordinator: lock hidden for $packageName, will relock on re-entry")
    }

    /** The lock screen was destroyed without being unlocked. */
    @Synchronized
    fun onLockClosed(packageName: String) {
        if (lockVisibleFor == packageName) lockVisibleFor = null
        clearCooldown()
        GuardLog.d("coordinator: lock closed for $packageName")
    }

    /** Everything relocks when the screen goes off. */
    @Synchronized
    fun onScreenOff() {
        unlockedPackages.clear()
        foregroundPackage = null
        clearCooldown()
        GuardLog.d("coordinator: screen off, all apps relocked")
    }

    /** Forgets all state, for when protection is switched off. */
    @Synchronized
    fun reset() {
        unlockedPackages.clear()
        foregroundPackage = null
        lockVisibleFor = null
        clearCooldown()
        GuardLog.d("coordinator: reset")
    }

    /** Current state, for logging. */
    @Synchronized
    fun describeState(): String =
        "foreground=$foregroundPackage lockVisibleFor=$lockVisibleFor " +
            "unlocked=$unlockedPackages lastLaunched=$lastLaunchedPackage"

    private fun clearCooldown() {
        lastLaunchedPackage = null
        lastLaunchedAtMs = 0L
    }
}
