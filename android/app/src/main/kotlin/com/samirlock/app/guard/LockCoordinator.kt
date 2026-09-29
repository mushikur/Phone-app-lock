package com.samirlock.app.guard

/**
 * Decides when the lock screen should appear.
 *
 * Deliberately free of Android imports — the current time is passed in — so the
 * rules that matter most are plain, readable Kotlin that can be reasoned about
 * and unit tested without a device.
 *
 * A single instance is shared by [GuardService] and the lock screen, which live
 * in the same process. Every entry point is synchronised because the service
 * polls from its own loop while the lock screen reports in from the main thread.
 */
object LockCoordinator {

    sealed interface Decision {
        /** Nothing to do. */
        data object None : Decision

        /** Show the lock screen for [packageName]. */
        data class ShowLock(val packageName: String) : Decision
    }

    /**
     * How long to ignore a repeat launch for the same package.
     *
     * Usage events trail the real foreground state by a tick or two, so without
     * this the same app would be detected again before the lock screen has been
     * reported as visible.
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
        if (packageName == selfPackage) return Decision.None

        if (packageName != foregroundPackage) {
            // Leaving an app relocks it.
            foregroundPackage?.let(unlockedPackages::remove)
            foregroundPackage = packageName
        }

        if (packageName !in lockedPackages) return Decision.None
        if (packageName in unlockedPackages) return Decision.None
        if (lockVisibleFor != null) return Decision.None
        if (packageName == lastLaunchedPackage &&
            nowMs - lastLaunchedAtMs < RELAUNCH_COOLDOWN_MS
        ) {
            return Decision.None
        }

        lastLaunchedPackage = packageName
        lastLaunchedAtMs = nowMs
        return Decision.ShowLock(packageName)
    }

    /** The lock screen is now on screen for [packageName]. */
    @Synchronized
    fun onLockShown(packageName: String) {
        lockVisibleFor = packageName
    }

    /** The user satisfied the lock for [packageName]. */
    @Synchronized
    fun onUnlocked(packageName: String) {
        unlockedPackages.add(packageName)
        foregroundPackage = packageName
        lockVisibleFor = null
        clearCooldown()
    }

    /**
     * The lock screen closed without being unlocked.
     *
     * The cooldown is cleared so that coming straight back to the app locks it
     * again immediately rather than slipping through the repeat-launch guard.
     */
    @Synchronized
    fun onLockClosed(packageName: String) {
        if (lockVisibleFor == packageName) lockVisibleFor = null
        clearCooldown()
    }

    /** Everything relocks when the screen goes off. */
    @Synchronized
    fun onScreenOff() {
        unlockedPackages.clear()
        foregroundPackage = null
        clearCooldown()
    }

    /** Forgets all state, for when protection is switched off. */
    @Synchronized
    fun reset() {
        unlockedPackages.clear()
        foregroundPackage = null
        lockVisibleFor = null
        clearCooldown()
    }

    private fun clearCooldown() {
        lastLaunchedPackage = null
        lastLaunchedAtMs = 0L
    }
}
