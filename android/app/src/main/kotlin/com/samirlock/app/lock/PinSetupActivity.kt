package com.samirlock.app.lock

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import com.samirlock.app.R
import com.samirlock.app.auth.PinPolicy
import com.samirlock.app.auth.PinVault
import com.samirlock.app.guard.GuardLog
import java.util.Arrays
import java.util.concurrent.Executors

/**
 * Creates or changes the PIN.
 *
 * Native rather than a Flutter screen so the digits never cross the
 * MethodChannel: they go from this keypad straight into the Keystore-backed
 * [PinVault]. The PIN is never logged, never put in a String, and never leaves
 * this process.
 */
class PinSetupActivity : Activity() {

    private lateinit var vault: PinVault
    private lateinit var pad: PinPadController
    private lateinit var dots: LinearLayout
    private lateinit var title: TextView
    private lateinit var subtitle: TextView
    private lateinit var error: TextView
    private lateinit var continueButton: Button

    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    /** The first entry, held only until it is confirmed. */
    private var firstEntry: CharArray? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GuardLog.configure(this)

        // A PIN being created deserves the same protection as one being entered.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )

        setContentView(R.layout.activity_pin_setup)
        vault = PinVault(this)

        title = findViewById(R.id.setup_title)
        subtitle = findViewById(R.id.setup_subtitle)
        error = findViewById(R.id.setup_error)
        dots = findViewById(R.id.setup_pin_dots)
        continueButton = findViewById(R.id.setup_continue)

        pad = PinPadController(
            root = findViewById(android.R.id.content),
            dotsContainer = dots,
            onChanged = ::onLengthChanged,
        )
        pad.setBiometricAvailable(false)

        continueButton.setOnClickListener { onContinue() }
        onLengthChanged(0)
    }

    override fun onDestroy() {
        firstEntry?.let { Arrays.fill(it, '\u0000') }
        firstEntry = null
        pad.release()
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun onLengthChanged(length: Int) {
        val longEnough = length >= PinPolicy.MIN_LENGTH
        continueButton.isEnabled = longEnough
        continueButton.alpha = if (longEnough) 1f else DISABLED_ALPHA
        if (length > 0) error.text = ""
    }

    private fun onContinue() {
        if (pad.currentLength() < PinPolicy.MIN_LENGTH) {
            showError(getString(R.string.pin_setup_too_short))
            return
        }

        val pending = firstEntry
        if (pending == null) {
            // First entry: remember it and ask for confirmation.
            firstEntry = pad.consume { it.copyOf() }
            pad.clear()
            title.setText(R.string.pin_setup_confirm_title)
            subtitle.setText(R.string.pin_setup_confirm_subtitle)
            error.text = ""
            return
        }

        val matches = pad.consume { PinPolicy.matches(pending, it) }
        if (!matches) {
            // Start over rather than letting the user retry the confirmation, so a
            // mistyped first entry cannot be saved by accident.
            Arrays.fill(pending, '\u0000')
            firstEntry = null
            pad.clear()
            title.setText(R.string.pin_setup_create_title)
            subtitle.setText(R.string.pin_setup_create_subtitle)
            showError(getString(R.string.pin_setup_mismatch))
            return
        }

        save(pending)
    }

    private fun save(pin: CharArray) {
        pad.isEnabled = false
        continueButton.isEnabled = false

        // PBKDF2 is deliberately slow, so it never runs on the main thread.
        worker.execute {
            val saved = vault.setPin(pin)
            Arrays.fill(pin, '\u0000')

            mainHandler.post {
                if (isFinishing || isDestroyed) return@post
                firstEntry = null

                if (saved) {
                    GuardLog.d("pin setup: PIN saved")
                    Toast.makeText(this, R.string.pin_setup_saved, Toast.LENGTH_SHORT).show()
                    setResult(RESULT_OK)
                    finish()
                } else {
                    pad.isEnabled = true
                    pad.clear()
                    title.setText(R.string.pin_setup_create_title)
                    subtitle.setText(R.string.pin_setup_create_subtitle)
                    showError(getString(R.string.pin_setup_failed))
                }
            }
        }
    }

    private fun showError(message: String) {
        error.text = message
        PinPadController.signalError(dots)
    }

    private companion object {
        const val DISABLED_ALPHA = 0.4f
    }
}
