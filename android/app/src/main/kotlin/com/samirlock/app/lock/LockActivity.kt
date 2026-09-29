package com.samirlock.app.lock

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.samirlock.app.R
import com.samirlock.app.guard.GuardLog
import com.samirlock.app.guard.LockCoordinator

/**
 * The lock screen.
 *
 * Plain Kotlin and framework views on purpose: this screen has to be on top of the
 * protected app almost immediately, and starting a Flutter engine here would add
 * hundreds of milliseconds and another way to fail. The Flutter side of the app
 * never renders this.
 *
 * The unlock button in this phase is a placeholder for testing the lock engine. It
 * is not authentication — no PIN, no biometrics, and no secret of any kind is
 * stored or checked.
 */
class LockActivity : Activity() {

    private var lockedPackage: String = ""
    private var wasUnlocked = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GuardLog.configure(this)

        // Keeps the lock screen out of screenshots and the recents thumbnail.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )

        setContentView(R.layout.activity_lock)
        bind(intent)

        findViewById<Button>(R.id.lock_unlock_button).setOnClickListener { unlock() }
    }

    /**
     * The activity is `singleTask`, so a lock for a different app arrives here
     * rather than as a second instance.
     */
    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        if (intent == null) return
        GuardLog.d("lock: onNewIntent")
        setIntent(intent)
        wasUnlocked = false
        bind(intent)
    }

    private fun bind(intent: Intent) {
        val packageName = intent.getStringExtra(EXTRA_PACKAGE_NAME).orEmpty()
        if (packageName.isEmpty()) {
            // Nothing to protect: never sit on screen blocking the user with no reason.
            GuardLog.w("lock: no package in intent, closing")
            finish()
            return
        }

        lockedPackage = packageName
        LockCoordinator.onLockShown(packageName)

        val appName = loadAppLabel(packageName)
        findViewById<TextView>(R.id.lock_app_name).text = appName
        findViewById<ImageView>(R.id.lock_app_icon).setImageDrawable(loadAppIcon(packageName))
        GuardLog.d("lock: showing for $packageName ($appName)")
    }

    private fun loadAppLabel(forPackage: String): String = runCatching {
        val info = packageManager.getApplicationInfo(forPackage, 0)
        packageManager.getApplicationLabel(info).toString()
    }.getOrDefault(forPackage)

    private fun loadAppIcon(forPackage: String) = runCatching {
        packageManager.getApplicationIcon(forPackage)
    }.getOrNull()

    private fun unlock() {
        GuardLog.d("lock: unlocked (test action) for $lockedPackage")
        wasUnlocked = true
        LockCoordinator.onUnlocked(lockedPackage)
        // No animation: the protected app should simply be there.
        finish()
        overridePendingTransition(0, 0)
    }

    /**
     * Back must not reveal the app underneath, so it behaves like Home instead.
     * The guard locks the app again the next time it is opened.
     */
    @Deprecated("Framework Activity has no back dispatcher; predictive back is off.")
    override fun onBackPressed() {
        GuardLog.d("lock: back pressed, going home")
        goHome()
    }

    /**
     * If the lock screen stops while the app behind it is still locked, it reports
     * itself hidden and stays alive.
     *
     * It deliberately does not finish here. The system stops this activity for
     * reasons that are not the user giving up — a transition, the protected app
     * drawing again, an OEM task shuffle — and finishing on any of those reveals
     * the very app that is supposed to be covered. Reporting "hidden" instead lets
     * the guard cover the app again the moment it is seen in the foreground.
     */
    override fun onStop() {
        super.onStop()
        if (!wasUnlocked) {
            GuardLog.d("lock: stopped while still locked, staying alive")
            LockCoordinator.onLockHidden(lockedPackage)
        }
    }

    override fun onDestroy() {
        GuardLog.d("lock: destroyed (wasUnlocked=$wasUnlocked)")
        if (!wasUnlocked) LockCoordinator.onLockClosed(lockedPackage)
        super.onDestroy()
    }

    private fun goHome() {
        val home = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { startActivity(home) }
            .onFailure { GuardLog.w("lock: could not go home", it) }
        finish()
        overridePendingTransition(0, 0)
    }

    companion object {
        private const val EXTRA_PACKAGE_NAME = "com.samirlock.app.extra.PACKAGE_NAME"

        fun intentFor(context: Context, lockedPackage: String): Intent =
            Intent(context, LockActivity::class.java)
                .putExtra(EXTRA_PACKAGE_NAME, lockedPackage)
    }
}
