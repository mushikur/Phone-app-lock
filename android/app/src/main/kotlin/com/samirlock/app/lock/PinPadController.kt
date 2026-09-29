package com.samirlock.app.lock

import android.content.Context
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import com.samirlock.app.R
import com.samirlock.app.auth.PinPolicy
import java.util.Arrays

/**
 * Binds the shared keypad layout and holds the digits being typed.
 *
 * The digits live in a [CharArray] that is zeroed the moment it is no longer
 * needed, rather than in a String, which would linger in memory until the
 * garbage collector happened to get to it.
 */
class PinPadController(
    root: View,
    dotsContainer: LinearLayout,
    private val onChanged: (length: Int) -> Unit,
    private val onBiometric: (() -> Unit)? = null,
) {

    private val context: Context = root.context
    private val dots = dotsContainer

    private var digits = CharArray(PinPolicy.MAX_LENGTH)
    private var length = 0

    /** Blocks input while a check is running or a lockout is in force. */
    var isEnabled: Boolean = true
        set(value) {
            field = value
            keys.forEach { it.isEnabled = value }
            biometricKey?.isEnabled = value
            keys.forEach { it.alpha = if (value) 1f else DISABLED_ALPHA }
        }

    private val keys: List<View> = listOf(
        R.id.key_0, R.id.key_1, R.id.key_2, R.id.key_3, R.id.key_4,
        R.id.key_5, R.id.key_6, R.id.key_7, R.id.key_8, R.id.key_9,
        R.id.key_delete,
    ).map(root::findViewById)

    private val biometricKey: ImageView? = root.findViewById(R.id.key_biometric)

    init {
        for (digit in 0..9) {
            val id = when (digit) {
                0 -> R.id.key_0
                1 -> R.id.key_1
                2 -> R.id.key_2
                3 -> R.id.key_3
                4 -> R.id.key_4
                5 -> R.id.key_5
                6 -> R.id.key_6
                7 -> R.id.key_7
                8 -> R.id.key_8
                else -> R.id.key_9
            }
            root.findViewById<View>(id).setOnClickListener { view ->
                view.tap()
                append(('0' + digit))
            }
        }

        root.findViewById<View>(R.id.key_delete).setOnClickListener { view ->
            view.tap()
            deleteLast()
        }

        biometricKey?.setOnClickListener { view ->
            view.tap()
            onBiometric?.invoke()
        }

        renderDots()
    }

    /** Shows the fingerprint key only when the device can actually use it. */
    fun setBiometricAvailable(available: Boolean) {
        biometricKey?.visibility = if (available) View.VISIBLE else View.INVISIBLE
    }

    fun currentLength(): Int = length

    /**
     * Hands the typed digits to [block] and clears them afterwards, so the PIN
     * exists for exactly as long as it takes to check it.
     */
    fun <T> consume(block: (CharArray) -> T): T {
        val snapshot = digits.copyOf(length)
        return try {
            block(snapshot)
        } finally {
            Arrays.fill(snapshot, '\u0000')
        }
    }

    fun clear() {
        Arrays.fill(digits, '\u0000')
        length = 0
        renderDots()
        onChanged(length)
    }

    /** Wipes the buffer for good; call when the screen goes away. */
    fun release() {
        Arrays.fill(digits, '\u0000')
        length = 0
    }

    private fun append(digit: Char) {
        if (!isEnabled || length >= PinPolicy.MAX_LENGTH) return
        digits[length++] = digit
        renderDots()
        onChanged(length)
    }

    private fun deleteLast() {
        if (!isEnabled || length == 0) return
        digits[--length] = '\u0000'
        renderDots()
        onChanged(length)
    }

    /**
     * One dot per digit typed, never fewer than the minimum PIN length, so the
     * user can see both what they have entered and how much is required.
     */
    private fun renderDots() {
        val slots = maxOf(PinPolicy.MIN_LENGTH, length)
        while (dots.childCount < slots) dots.addView(newDot())
        while (dots.childCount > slots) dots.removeViewAt(dots.childCount - 1)

        for (index in 0 until dots.childCount) {
            dots.getChildAt(index).setBackgroundResource(
                if (index < length) R.drawable.pin_dot_filled else R.drawable.pin_dot_empty,
            )
        }
    }

    private fun newDot(): View = View(context).apply {
        val size = (DOT_SIZE_DP * context.resources.displayMetrics.density).toInt()
        val spacing = (DOT_SPACING_DP * context.resources.displayMetrics.density).toInt()
        layoutParams = LinearLayout.LayoutParams(size, size).apply {
            marginStart = spacing
            marginEnd = spacing
        }
    }

    private fun View.tap() {
        performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
    }

    companion object {
        private const val DOT_SIZE_DP = 11f
        private const val DOT_SPACING_DP = 7f
        private const val DISABLED_ALPHA = 0.4f

        /** Shakes the dots to signal a rejected PIN, alongside the error text. */
        fun signalError(dots: ViewGroup) {
            dots.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            dots.animate()
                .translationX(SHAKE_DP)
                .setDuration(50)
                .withEndAction {
                    dots.animate()
                        .translationX(-SHAKE_DP)
                        .setDuration(50)
                        .withEndAction {
                            dots.animate().translationX(0f).setDuration(50).start()
                        }
                        .start()
                }
                .start()
        }

        private const val SHAKE_DP = 14f
    }
}
