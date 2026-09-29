package com.samirlock.app.guard

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * The rules that decide whether a locked app stays covered.
 *
 * [LockCoordinator] is a process-wide singleton, so every test starts from a
 * known state.
 */
class LockCoordinatorTest {

    private val locked = setOf(CHAT, GALLERY)

    @Before
    fun reset() {
        LockCoordinator.reset()
    }

    private fun foreground(
        packageName: String,
        nowMs: Long = 0L,
        lockedPackages: Set<String> = locked,
    ) = LockCoordinator.onForegroundPackage(packageName, lockedPackages, SELF, nowMs)

    @Test
    fun `locked app entering the foreground shows the lock`() {
        val decision = foreground(CHAT)

        assertEquals(LockCoordinator.Decision.ShowLock(CHAT), decision)
    }

    @Test
    fun `an app that is not locked is left alone`() {
        assertTrue(foreground(LAUNCHER) is LockCoordinator.Decision.None)
    }

    @Test
    fun `the lock is not shown twice while it is already visible`() {
        foreground(CHAT)
        LockCoordinator.onLockShown(CHAT)

        assertTrue(foreground(CHAT, nowMs = 5_000L) is LockCoordinator.Decision.None)
    }

    @Test
    fun `an unlocked app opens without the lock`() {
        foreground(CHAT)
        LockCoordinator.onUnlocked(CHAT)

        assertTrue(foreground(CHAT, nowMs = 2_000L) is LockCoordinator.Decision.None)
    }

    @Test
    fun `leaving an app relocks it`() {
        foreground(CHAT)
        LockCoordinator.onUnlocked(CHAT)
        foreground(LAUNCHER, nowMs = 2_000L)

        assertEquals(
            LockCoordinator.Decision.ShowLock(CHAT),
            foreground(CHAT, nowMs = 3_000L),
        )
    }

    @Test
    fun `switching between two locked apps locks each of them`() {
        foreground(CHAT)
        LockCoordinator.onUnlocked(CHAT)

        assertEquals(
            LockCoordinator.Decision.ShowLock(GALLERY),
            foreground(GALLERY, nowMs = 1_000L),
        )
        LockCoordinator.onUnlocked(GALLERY)

        // Chat was left behind when Gallery came forward, so it locks again.
        assertEquals(
            LockCoordinator.Decision.ShowLock(CHAT),
            foreground(CHAT, nowMs = 2_000L),
        )
    }

    @Test
    fun `our own screens never count as leaving the unlocked app`() {
        foreground(CHAT)
        LockCoordinator.onUnlocked(CHAT)

        assertTrue(foreground(SELF, nowMs = 1_000L) is LockCoordinator.Decision.None)

        // Coming back from our own screen must not have relocked Chat.
        assertTrue(foreground(CHAT, nowMs = 2_000L) is LockCoordinator.Decision.None)
    }

    @Test
    fun `the screen going off relocks everything`() {
        foreground(CHAT)
        LockCoordinator.onUnlocked(CHAT)
        LockCoordinator.onScreenOff()

        assertEquals(
            LockCoordinator.Decision.ShowLock(CHAT),
            foreground(CHAT, nowMs = 1_000L),
        )
    }

    @Test
    fun `a repeat launch within the cooldown is suppressed`() {
        assertEquals(LockCoordinator.Decision.ShowLock(CHAT), foreground(CHAT, nowMs = 0L))

        // The lock has not reported itself visible yet, as usage events lag.
        assertTrue(foreground(CHAT, nowMs = 400L) is LockCoordinator.Decision.None)
    }

    @Test
    fun `dismissing the lock relocks immediately rather than waiting out the cooldown`() {
        foreground(CHAT, nowMs = 0L)
        LockCoordinator.onLockShown(CHAT)
        LockCoordinator.onLockHidden(CHAT)

        // Regression: the repeat-launch guard used to swallow this, leaving the
        // protected app exposed on re-entry.
        assertEquals(
            LockCoordinator.Decision.ShowLock(CHAT),
            foreground(CHAT, nowMs = 200L),
        )
    }

    @Test
    fun `a closed lock does not leave the app marked as unlocked`() {
        foreground(CHAT)
        LockCoordinator.onLockShown(CHAT)
        LockCoordinator.onLockClosed(CHAT)

        assertEquals(
            LockCoordinator.Decision.ShowLock(CHAT),
            foreground(CHAT, nowMs = 5_000L),
        )
    }

    @Test
    fun `unconfirmed launches are counted and cleared when the lock appears`() {
        foreground(CHAT, nowMs = 0L)
        assertEquals(1, LockCoordinator.unconfirmedLaunchCount())

        foreground(CHAT, nowMs = 2_000L)
        assertEquals(2, LockCoordinator.unconfirmedLaunchCount())

        LockCoordinator.onLockShown(CHAT)
        assertEquals(0, LockCoordinator.unconfirmedLaunchCount())
    }

    @Test
    fun `removing an app from the locked list stops locking it`() {
        foreground(CHAT)
        LockCoordinator.onUnlocked(CHAT)
        foreground(LAUNCHER, nowMs = 1_000L)

        assertTrue(
            foreground(CHAT, nowMs = 2_000L, lockedPackages = setOf(GALLERY))
                is LockCoordinator.Decision.None,
        )
    }

    private companion object {
        const val SELF = "com.samirlock.app"
        const val CHAT = "com.example.chat"
        const val GALLERY = "com.example.gallery"
        const val LAUNCHER = "com.sec.android.app.launcher"
    }
}
