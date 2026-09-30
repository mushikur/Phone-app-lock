package com.samirlock.app.permissions

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager

/**
 * What this particular phone is likely to do to a background service.
 *
 * Android gives two honest signals — whether the app is background restricted,
 * and whether it is exempt from battery optimisation — and nothing more. The
 * aggressive parts of OEM power management (MIUI's Autostart, vivo's background
 * list, ColorOS's startup manager) have no public API to read or change, so the
 * most that can be done is recognise the manufacturer and tell the user, in one
 * line, where the setting lives on their phone.
 *
 * Nothing here works around a restriction. It only reports and explains.
 */
object DeviceCompatibility {

    /** Which set of instructions fits this phone. */
    enum class Vendor(val wireName: String) {
        SAMSUNG("samsung"),
        XIAOMI("xiaomi"),
        OPPO("oppo"),
        ONEPLUS("oneplus"),
        VIVO("vivo"),
        REALME("realme"),
        HUAWEI("huawei"),
        MOTOROLA("motorola"),
        GOOGLE("google"),
        OTHER("other"),
    }

    fun vendor(): Vendor {
        val name = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()

        return when {
            name.contains("samsung") -> Vendor.SAMSUNG
            name.contains("xiaomi") || brand.contains("redmi") ||
                brand.contains("poco") -> Vendor.XIAOMI

            name.contains("oneplus") -> Vendor.ONEPLUS
            name.contains("realme") -> Vendor.REALME
            name.contains("oppo") -> Vendor.OPPO
            name.contains("vivo") -> Vendor.VIVO
            name.contains("huawei") || name.contains("honor") -> Vendor.HUAWEI
            name.contains("motorola") || name.contains("lenovo") -> Vendor.MOTOROLA
            name.contains("google") -> Vendor.GOOGLE
            else -> Vendor.OTHER
        }
    }

    /**
     * True when Android says this app is background restricted.
     *
     * The clearest signal there is: the user, or the system, has put the app in
     * a state where it cannot run freely in the background.
     */
    fun isBackgroundRestricted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        val manager = context.getSystemService(ActivityManager::class.java) ?: return false
        return runCatching { manager.isBackgroundRestricted }.getOrDefault(false)
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val power = context.getSystemService(PowerManager::class.java) ?: return false
        return runCatching {
            power.isIgnoringBatteryOptimizations(context.packageName)
        }.getOrDefault(false)
    }

    /**
     * Whether background guidance is worth showing at all.
     *
     * Deliberately not shown to everyone: a phone that already exempts the app
     * has nothing to fix, and telling every user to go changing battery settings
     * is noise that trains people to ignore real warnings.
     */
    fun needsBackgroundGuidance(context: Context): Boolean {
        if (isBackgroundRestricted(context)) return true
        if (isIgnoringBatteryOptimizations(context)) return false

        // These vendors stop background services aggressively enough that the
        // battery exemption genuinely matters. On stock-like Android it usually
        // does not, so the advice is left out rather than given needlessly.
        return when (vendor()) {
            Vendor.SAMSUNG, Vendor.XIAOMI, Vendor.OPPO, Vendor.ONEPLUS,
            Vendor.VIVO, Vendor.REALME, Vendor.HUAWEI,
            -> true

            Vendor.MOTOROLA, Vendor.GOOGLE, Vendor.OTHER -> false
        }
    }

    fun describe(context: Context): Map<String, Any?> = mapOf(
        "vendor" to vendor().wireName,
        "manufacturer" to Build.MANUFACTURER,
        "sdkInt" to Build.VERSION.SDK_INT,
        "androidRelease" to Build.VERSION.RELEASE,
        "isBackgroundRestricted" to isBackgroundRestricted(context),
        "isIgnoringBatteryOptimizations" to isIgnoringBatteryOptimizations(context),
        "needsBackgroundGuidance" to needsBackgroundGuidance(context),
    )
}
