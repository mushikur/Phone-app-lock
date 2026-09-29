package com.samirlock.app.auth

/**
 * Rules for what counts as an acceptable PIN.
 *
 * Pure Kotlin and free of Android imports so the rules can be read, reasoned
 * about and tested in isolation.
 */
object PinPolicy {

    const val MIN_LENGTH = 4
    const val MAX_LENGTH = 8

    sealed interface Result {
        data object Valid : Result
        data object TooShort : Result
        data object TooLong : Result
        data object NotDigits : Result
    }

    fun validate(pin: CharArray): Result = when {
        pin.size < MIN_LENGTH -> Result.TooShort
        pin.size > MAX_LENGTH -> Result.TooLong
        pin.any { it !in '0'..'9' } -> Result.NotDigits
        else -> Result.Valid
    }

    /** Constant-time comparison, so confirmation never leaks timing about the PIN. */
    fun matches(first: CharArray, second: CharArray): Boolean {
        if (first.size != second.size) return false
        var difference = 0
        for (index in first.indices) {
            difference = difference or (first[index].code xor second[index].code)
        }
        return difference == 0
    }
}
