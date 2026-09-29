package com.samirlock.app.inventory

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build

/**
 * Enumerates the launchable applications installed on the device.
 *
 * Visibility comes from the `<queries>` declaration for MAIN/LAUNCHER in the
 * manifest rather than QUERY_ALL_PACKAGES, which keeps the permission surface
 * minimal. Nothing here touches the network — the inventory is purely local.
 */
class InstalledAppsProvider(context: Context) {

    private val appContext = context.applicationContext
    private val packageManager: PackageManager = appContext.packageManager

    /**
     * Returns every launchable app except this one, sorted by display name.
     *
     * This is an expensive call — it rasterises one icon per installed app — and
     * is expected to run off the platform thread.
     */
    fun loadInstalledApps(): List<Map<String, Any?>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return queryLauncherActivities(intent)
            .asSequence()
            .map { it.activityInfo.applicationInfo }
            .filter { it.packageName != appContext.packageName }
            .distinctBy { it.packageName }
            .map(::describe)
            .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it[KEY_APP_NAME] as String })
            .toList()
    }

    private fun queryLauncherActivities(intent: Intent): List<ResolveInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(0L),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, 0)
        }

    private fun describe(info: ApplicationInfo): Map<String, Any?> = mapOf(
        KEY_PACKAGE_NAME to info.packageName,
        KEY_APP_NAME to packageManager.getApplicationLabel(info).toString(),
        KEY_IS_SYSTEM_APP to isSystemApp(info),
        KEY_ICON to loadIcon(info),
    )

    private fun isSystemApp(info: ApplicationInfo): Boolean =
        (info.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP)) != 0

    private fun loadIcon(info: ApplicationInfo): ByteArray? = runCatching {
        IconEncoder.encode(packageManager.getApplicationIcon(info))
    }.getOrNull()

    private companion object {
        const val KEY_PACKAGE_NAME = "packageName"
        const val KEY_APP_NAME = "appName"
        const val KEY_IS_SYSTEM_APP = "isSystemApp"
        const val KEY_ICON = "icon"
    }
}
