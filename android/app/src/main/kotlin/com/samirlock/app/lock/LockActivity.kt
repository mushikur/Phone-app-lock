package com.samirlock.app.lock

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.fragment.app.FragmentActivity
import com.samirlock.app.MainActivity
import com.samirlock.app.R
import com.samirlock.app.auth.BiometricAuthenticator
import com.samirlock.app.auth.LockoutPolicy
import com.samirlock.app.auth.LockoutStore
import com.samirlock.app.auth.PinPolicy
import com.samirlock.app.auth.PinVault
import com.samirlock.app.guard.GuardLog
import com.samirlock.app.guard.LockCoordinator
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * The lock screen.
 *
 * Plain Kotlin and framework views on purpose: this screen has to be on top of the
 * protected app almost immediately, and starting a Flutter engine here would add
 * hundreds of milliseconds and another way to fail. The Flutter side of the app
 * never renders this, and has no way to release a lock — only a successful
 * authentication here does that.
 */
class LockActivity : FragmentActivity() {

    private lateinit var vault: PinVault
    private lateinit var lockoutStore: LockoutStore
    private lateinit var biometrics: BiometricAuthenticator
    private lateinit var pad: PinPadController

    private lateinit var dots: LinearLayout
    private lateinit var errorView: TextView
    private lateinit var headline: TextView
    private lateinit var keypad: View
    private lateinit var noPinPanel: View

    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    private var lockedPackage: String = ""
    private var wasUnlocked = false
    private var isChecking = false
    private var lockoutTimer: CountDownTimer? = null
    private var biometricPromptShowing = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GuardLog.configure(this)

        // Keeps the lock screen out of screenshots and the recents thumbnail.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )

        setContentView(R.layout.activity_lock)

        vault = PinVault(this)
        lockoutStore = LockoutStore(this)
        biometrics = BiometricAuthenticator(this)

        dots = findViewById(R.id.lock_pin_dots)
        errorView = findViewById(R.id.lock_error)
        headline = findViewById(R.id.lock_headline)
        keypad = findViewById(R.id.lock_keypad)
        noPinPanel = findViewById(R.id.lock_no_pin)

        pad = PinPadController(
            root = findViewById(android.R.id.content),
            dotsContainer = dots,
            onChanged = ::onPinLengthChanged,
            onBiometric = ::promptBiometric,
        )

        findViewById<Button>(R.id.lock_open_app).setOnClickListener { openSamirLock() }

        // Back must not reveal the app underneath, so it behaves like Home.
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    GuardLog.d("lock: back pressed, going home")
                    goHome()
                }
            },
        )

        bind(intent)
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
        pad.clear()
        errorView.text = ""
        bind(intent)
    }

    private fun bind(intent: Intent) {
        val packageName = intent.getStringExtra(EXTRA_PACKAGE_NAME).orEmpty()
        if (packageName.isEmpty()) {
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

        if (!vault.hasPin()) {
            showNoPinState()
            return
        }

        val available = biometrics.availability() == BiometricAuthenticator.Availability.AVAILABLE
        pad.setBiometricAvailable(available)

        applyLockout(lockoutStore.remainingLockoutMs())

        // Offer the fastest route first; the PIN pad is right there behind it.
        if (available && !biometricPromptShowing) promptBiometric()
    }

    /**
     * Without a PIN there is nothing to authenticate against, so rather than
     * trapping the user behind a screen they cannot pass, the way into Samir Lock
     * is offered.
     */
    private fun showNoPinState() {
        headline.setText(R.string.lock_no_pin_title)
        keypad.visibility = View.GONE
        dots.visibility = View.GONE
        noPinPanel.visibility = View.VISIBLE
    }

    private fun onPinLengthChanged(length: Int) {
        if (length > 0) errorView.text = ""
        if (length >= PinPolicy.MIN_LENGTH && !isChecking) {
            // Auto-submit at the minimum length would block longer PINs, so the
            // check runs on every keypress from four digits up: a 4-digit PIN
            // unlocks the moment it is complete, and a longer one still works.
            submit()
        }
    }

    private fun submit() {
        if (isChecking || lockoutStore.remainingLockoutMs() > 0L) return

        isChecking = true
        pad.isEnabled = false

        // PBKDF2 is deliberately slow; it never runs on the main thread.
        val attempt = pad.consume { it.copyOf() }
        worker.execute {
            val accepted = vault.verify(attempt)
            java.util.Arrays.fill(attempt, '\u0000')

            mainHandler.post {
                if (isFinishing || isDestroyed) return@post
                isChecking = false
                if (accepted) onAuthenticated("pin") else onWrongPin()
            }
        }
    }

    private fun onWrongPin() {
        val delay = lockoutStore.recordFailure()
        // Never log the PIN, only that an attempt failed.
        GuardLog.d("lock: wrong PIN (attempt ${lockoutStore.failedAttempts})")

        pad.clear()
        pad.isEnabled = true
        PinPadController.signalError(dots)

        if (delay > 0L) {
            applyLockout(delay)
            return
        }

        val remaining = LockoutPolicy.attemptsBeforeDelay(lockoutStore.failedAttempts)
        errorView.text = if (remaining in 1..2) {
            getString(R.string.lock_attempts_left, remaining)
        } else {
            getString(R.string.lock_wrong_pin)
        }
    }

    /** Disables the keypad and counts down, so the wait is visible rather than mysterious. */
    private fun applyLockout(remainingMs: Long) {
        lockoutTimer?.cancel()
        lockoutTimer = null

        if (remainingMs <= 0L) {
            pad.isEnabled = true
            return
        }

        pad.isEnabled = false
        lockoutTimer = object : CountDownTimer(remainingMs, 1_000L) {
            override fun onTick(millisUntilFinished: Long) {
                errorView.text =
                    getString(R.string.lock_too_many_attempts, formatDuration(millisUntilFinished))
            }

            override fun onFinish() {
                errorView.text = ""
                pad.isEnabled = true
            }
        }.also(CountDownTimer::start)
    }

    private fun formatDuration(millis: Long): String {
        val totalSeconds = (millis / 1_000L).coerceAtLeast(1L)
        val minutes = TimeUnit.SECONDS.toMinutes(totalSeconds)
        val seconds = totalSeconds - TimeUnit.MINUTES.toSeconds(minutes)
        return if (minutes > 0) "${minutes}m ${seconds}s" else "${seconds}s"
    }

    private fun promptBiometric() {
        if (biometricPromptShowing || wasUnlocked) return
        if (lockoutStore.remainingLockoutMs() > 0L) return

        biometricPromptShowing = true
        biometrics.authenticate(this) { outcome ->
            biometricPromptShowing = false
            when (outcome) {
                is BiometricAuthenticator.Outcome.Succeeded -> onAuthenticated("biometric")

                // Cancelling is a choice, not a failure: the PIN pad is already on
                // screen behind the prompt, so there is nothing to say.
                is BiometricAuthenticator.Outcome.Cancelled -> Unit

                is BiometricAuthenticator.Outcome.LockedOut -> {
                    pad.setBiometricAvailable(false)
                    errorView.text = outcome.message
                }

                is BiometricAuthenticator.Outcome.Failed -> {
                    errorView.text = outcome.message
                }
            }
        }
    }

    /**
     * The single point at which a lock is released, and it is only ever reached
     * from a successful check on this device.
     */
    private fun onAuthenticated(method: String) {
        GuardLog.d("lock: unlocked via $method for $lockedPackage")
        wasUnlocked = true
        lockoutStore.recordSuccess()
        LockCoordinator.onUnlocked(lockedPackage)
        pad.release()
        finish()
        overridePendingTransition(0, 0)
    }

    private fun loadAppLabel(forPackage: String): String = runCatching {
        val info = packageManager.getApplicationInfo(forPackage, 0)
        packageManager.getApplicationLabel(info).toString()
    }.getOrDefault(forPackage)

    private fun loadAppIcon(forPackage: String) = runCatching {
        packageManager.getApplicationIcon(forPackage)
    }.getOrNull()

    private fun openSamirLock() {
        runCatching {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }.onFailure { GuardLog.w("lock: could not open Samir Lock", it) }
        finish()
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
            // Anything half-typed is discarded rather than waiting on screen.
            pad.clear()
            LockCoordinator.onLockHidden(lockedPackage)
        }
    }

    override fun onDestroy() {
        GuardLog.d("lock: destroyed (wasUnlocked=$wasUnlocked)")
        lockoutTimer?.cancel()
        pad.release()
        worker.shutdownNow()
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
