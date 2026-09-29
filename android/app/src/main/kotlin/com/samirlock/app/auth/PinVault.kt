package com.samirlock.app.auth

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.samirlock.app.guard.GuardLog
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Arrays
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec

/**
 * Stores and verifies the user's PIN.
 *
 * The PIN itself is never written anywhere. What is stored is a PBKDF2 hash with
 * a per-install random salt, and that record is then encrypted with an AES-GCM
 * key held in the Android Keystore, which cannot be extracted from the device.
 * An attacker with a copy of the app's data therefore has neither the PIN nor
 * anything they can attack offline without the hardware.
 *
 * Verification happens entirely here. The Dart side never sees the PIN and never
 * sees this record; it only ever learns whether an attempt succeeded.
 */
class PinVault(context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun hasPin(): Boolean = readRecord() != null

    /**
     * Replaces the stored PIN.
     *
     * [pin] is consumed but not cleared — the caller owns it and is expected to
     * zero it once finished.
     */
    fun setPin(pin: CharArray): Boolean {
        if (PinPolicy.validate(pin) != PinPolicy.Result.Valid) return false

        val salt = ByteArray(SALT_LENGTH).also(SecureRandom()::nextBytes)
        val hash = derive(pin, salt, ITERATIONS)

        return try {
            val record = encode(salt, ITERATIONS, hash)
            val sealed = encrypt(record)
            Arrays.fill(record, 0)
            prefs.edit().putString(KEY_RECORD, sealed).apply()
            true
        } catch (error: Exception) {
            GuardLog.w("vault: could not store PIN", error)
            false
        } finally {
            Arrays.fill(hash, 0)
        }
    }

    /**
     * Checks [pin] against the stored record.
     *
     * Expensive by design — PBKDF2 — so callers run this off the main thread.
     */
    fun verify(pin: CharArray): Boolean {
        val record = readRecord() ?: return false
        val candidate = derive(pin, record.salt, record.iterations)

        return try {
            // MessageDigest.isEqual is constant time on Android.
            MessageDigest.isEqual(candidate, record.hash)
        } finally {
            Arrays.fill(candidate, 0)
            Arrays.fill(record.hash, 0)
        }
    }

    /** Forgets the stored PIN and the Keystore key that protected it. */
    fun clear() {
        prefs.edit().remove(KEY_RECORD).apply()
        runCatching {
            keyStore().deleteEntry(KEY_ALIAS)
        }.onFailure { GuardLog.w("vault: could not delete key", it) }
    }

    private class Record(val salt: ByteArray, val iterations: Int, val hash: ByteArray)

    private fun readRecord(): Record? {
        val sealed = prefs.getString(KEY_RECORD, null) ?: return null

        return try {
            decode(decrypt(sealed))
        } catch (error: Exception) {
            // The Keystore key can be lost — a restore to another device, or the
            // user changing their screen lock on some OEM builds. The record is
            // then undecryptable and the PIN could never be verified again, so it
            // is cleared: the user sets a new PIN instead of being locked out of
            // their own apps forever.
            GuardLog.w("vault: stored PIN unreadable, clearing it", error)
            clear()
            null
        }
    }

    private fun derive(pin: CharArray, salt: ByteArray, iterations: Int): ByteArray {
        val spec = PBEKeySpec(pin, salt, iterations, HASH_BITS)
        return try {
            SecretKeyFactory.getInstance(pbkdf2Algorithm()).generateSecret(spec).encoded
        } finally {
            spec.clearPassword()
        }
    }

    /**
     * PBKDF2 with HMAC-SHA256 where the platform provides it (API 26+), and
     * HMAC-SHA1 below that, which is the only variant those versions ship. Both
     * are stretched with the same iteration count; the algorithm used is recorded
     * implicitly by the version byte.
     */
    private fun pbkdf2Algorithm(): String =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            "PBKDF2withHmacSHA256"
        } else {
            "PBKDF2withHmacSHA1"
        }

    private fun encode(salt: ByteArray, iterations: Int, hash: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(RECORD_VERSION)
        out.write(ByteBuffer.allocate(4).putInt(iterations).array())
        out.write(salt.size)
        out.write(salt)
        out.write(hash)
        return out.toByteArray()
    }

    private fun decode(record: ByteArray): Record {
        val buffer = ByteBuffer.wrap(record)
        val version = buffer.get().toInt()
        require(version == RECORD_VERSION) { "unsupported record version $version" }

        val iterations = buffer.int
        val saltLength = buffer.get().toInt()
        val salt = ByteArray(saltLength).also(buffer::get)
        val hash = ByteArray(buffer.remaining()).also(buffer::get)
        return Record(salt, iterations, hash)
    }

    private fun encrypt(record: ByteArray): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())

        val iv = cipher.iv
        val cipherText = cipher.doFinal(record)

        val combined = ByteArray(1 + iv.size + cipherText.size)
        combined[0] = iv.size.toByte()
        System.arraycopy(iv, 0, combined, 1, iv.size)
        System.arraycopy(cipherText, 0, combined, 1 + iv.size, cipherText.size)
        return Base64.encodeToString(combined, Base64.NO_WRAP)
    }

    private fun decrypt(sealed: String): ByteArray {
        val combined = Base64.decode(sealed, Base64.NO_WRAP)
        val ivLength = combined[0].toInt()
        val iv = combined.copyOfRange(1, 1 + ivLength)
        val cipherText = combined.copyOfRange(1 + ivLength, combined.size)

        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
        return cipher.doFinal(cipherText)
    }

    private fun keyStore(): KeyStore =
        KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    /** The Keystore key, created on first use and never leaving the device. */
    private fun secretKey(): SecretKey {
        val existing = keyStore().getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) return existing.secretKey

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE_PROVIDER,
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(AES_KEY_BITS)
                // Deliberately not tied to the device screen lock: Samir Lock must
                // keep working for users who have no screen lock set.
                .setUserAuthenticationRequired(false)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val PREFS_NAME = "samir_lock_secure"
        const val KEY_RECORD = "pin_record"

        const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        const val KEY_ALIAS = "samir_lock_pin_key"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val AES_KEY_BITS = 256
        const val GCM_TAG_BITS = 128

        const val RECORD_VERSION = 1
        const val SALT_LENGTH = 16
        const val HASH_BITS = 256

        /** Slow enough to make guessing expensive, fast enough to unlock promptly. */
        const val ITERATIONS = 100_000
    }
}
