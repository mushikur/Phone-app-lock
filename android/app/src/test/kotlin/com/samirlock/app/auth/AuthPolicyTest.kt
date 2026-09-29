package com.samirlock.app.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The backoff that stands between a guesser and a locked app. */
class LockoutPolicyTest {

    @Test
    fun `the first few wrong attempts are not delayed`() {
        for (attempt in 1..LockoutPolicy.FREE_ATTEMPTS) {
            assertEquals(
                "attempt $attempt should not be delayed",
                0L,
                LockoutPolicy.delayAfter(attempt),
            )
        }
    }

    @Test
    fun `the delay grows with each further mistake`() {
        assertEquals(30_000L, LockoutPolicy.delayAfter(5))
        assertEquals(60_000L, LockoutPolicy.delayAfter(6))
        assertEquals(120_000L, LockoutPolicy.delayAfter(7))
        assertEquals(240_000L, LockoutPolicy.delayAfter(8))
    }

    @Test
    fun `the delay is capped, so the owner is never locked out for good`() {
        assertEquals(300_000L, LockoutPolicy.delayAfter(9))
        assertEquals(300_000L, LockoutPolicy.delayAfter(50))
        // No overflow into a negative or absurd wait at extreme counts.
        assertEquals(300_000L, LockoutPolicy.delayAfter(Int.MAX_VALUE))
    }

    @Test
    fun `remaining attempts count down to zero and stay there`() {
        assertEquals(4, LockoutPolicy.attemptsBeforeDelay(0))
        assertEquals(1, LockoutPolicy.attemptsBeforeDelay(3))
        assertEquals(0, LockoutPolicy.attemptsBeforeDelay(4))
        assertEquals(0, LockoutPolicy.attemptsBeforeDelay(99))
    }
}

/** What counts as an acceptable PIN. */
class PinPolicyTest {

    @Test
    fun `a PIN shorter than four digits is rejected`() {
        assertEquals(PinPolicy.Result.TooShort, PinPolicy.validate("123".toCharArray()))
        assertEquals(PinPolicy.Result.TooShort, PinPolicy.validate(CharArray(0)))
    }

    @Test
    fun `a PIN longer than the maximum is rejected`() {
        assertEquals(
            PinPolicy.Result.TooLong,
            PinPolicy.validate("123456789".toCharArray()),
        )
    }

    @Test
    fun `anything that is not a digit is rejected`() {
        assertEquals(PinPolicy.Result.NotDigits, PinPolicy.validate("12a4".toCharArray()))
        assertEquals(PinPolicy.Result.NotDigits, PinPolicy.validate("12 4".toCharArray()))
    }

    @Test
    fun `four to eight digits are accepted`() {
        assertEquals(PinPolicy.Result.Valid, PinPolicy.validate("1234".toCharArray()))
        assertEquals(PinPolicy.Result.Valid, PinPolicy.validate("12345678".toCharArray()))
    }

    @Test
    fun `matching compares the whole PIN`() {
        assertTrue(PinPolicy.matches("1234".toCharArray(), "1234".toCharArray()))
        assertFalse(PinPolicy.matches("1234".toCharArray(), "1235".toCharArray()))
        assertFalse(PinPolicy.matches("1234".toCharArray(), "12345".toCharArray()))
        assertFalse(PinPolicy.matches("1234".toCharArray(), CharArray(0)))
    }
}
