package com.samirlock.app.auth

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.samirlock.app.R
import com.samirlock.app.guard.GuardLog

/**
 * Wraps AndroidX [BiometricPrompt] for the lock screen.
 *
 * The platform owns the prompt, the sensor and the matching; nothing biometric
 * is read, copied or stored here — the app only ever learns that the system
 * accepted the user.
 */
class BiometricAuthenticator(private val activity: FragmentActivity) {

    /** What the lock screen should do about biometrics on this device. */
    enum class Availability {
        /** Enrolled and usable. */
        AVAILABLE,

        /** Hardware exists but nothing is enrolled. */
        NOT_ENROLLED,

        /** No hardware, or it is permanently unusable. */
        UNAVAILABLE,

        /** Usable later, but not right now (hardware busy, or locked out). */
        TEMPORARILY_UNAVAILABLE,
    }

    sealed interface Outcome {
        data object Succeeded : Outcome

        /** The user dismissed the prompt or chose to use their PIN. */
        data object Cancelled : Outcome

        /** Too many failed biometric attempts; the platform closed the door. */
        data class LockedOut(val message: String) : Outcome

        /** Anything else the platform reported. */
        data class Failed(val message: String) : Outcome
    }

    fun availability(): Availability = availabilityOf(this.activity)

    /**
     * Shows the system prompt.
     *
     * [onOutcome] is always called on the main thread, exactly once per prompt
     * dismissal. Failures to recognise a finger are handled inside the prompt and
     * do not end it.
     */
    fun authenticate(context: Context, onOutcome: (Outcome) -> Unit) {
        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(context),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: BiometricPrompt.AuthenticationResult,
                ) {
                    GuardLog.d("biometric: succeeded")
                    onOutcome(Outcome.Succeeded)
                }

                override fun onAuthenticationError(
                    errorCode: Int,
                    errString: CharSequence,
                ) {
                    GuardLog.d("biometric: error $errorCode")
                    onOutcome(toOutcome(errorCode, errString.toString()))
                }

                override fun onAuthenticationFailed() {
                    // Not recognised. The prompt stays open and tells the user;
                    // nothing for the lock screen to do.
                    GuardLog.d("biometric: not recognised")
                }
            },
        )

        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(activity.getString(R.string.biometric_title))
            .setSubtitle(activity.getString(R.string.biometric_subtitle))
            .setNegativeButtonText(activity.getString(R.string.biometric_use_pin))
            .setConfirmationRequired(false)
            .build()

        runCatching { prompt.authenticate(info) }
            .onFailure {
                GuardLog.w("biometric: could not show prompt", it)
                onOutcome(Outcome.Failed(activity.getString(R.string.biometric_unavailable)))
            }
    }

    companion object {
        fun availabilityOf(context: Context): Availability {
            val manager = BiometricManager.from(context)
            // BIOMETRIC_WEAK covers strong sensors too, so asking for strong first and
            // falling back keeps face unlock usable on devices that classify it as
            // weak, without silently downgrading where a strong sensor exists.
            val authenticators = if (
                manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
                BiometricManager.BIOMETRIC_SUCCESS
            ) {
                BiometricManager.Authenticators.BIOMETRIC_STRONG
            } else {
                BiometricManager.Authenticators.BIOMETRIC_WEAK
            }

            return when (manager.canAuthenticate(authenticators)) {
                BiometricManager.BIOMETRIC_SUCCESS -> Availability.AVAILABLE
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> Availability.NOT_ENROLLED
                BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE ->
                    Availability.TEMPORARILY_UNAVAILABLE

                else -> Availability.UNAVAILABLE
            }
        }
    }

    private fun toOutcome(errorCode: Int, message: String): Outcome = when (errorCode) {
        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
        BiometricPrompt.ERROR_USER_CANCELED,
        BiometricPrompt.ERROR_CANCELED,
        -> Outcome.Cancelled

        BiometricPrompt.ERROR_LOCKOUT,
        BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
        -> Outcome.LockedOut(activity.getString(R.string.biometric_locked_out))

        else -> Outcome.Failed(message)
    }
}
