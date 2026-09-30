package com.samirlock.app.notifications

import android.app.NotificationManager
import android.content.Context
import com.samirlock.app.guard.GuardLog
import org.json.JSONArray
import org.json.JSONObject

/**
 * Remembers which notification channel each locked app posts through, and how
 * important the system says that channel is.
 *
 * This is the only way Samir Lock can know whether an app is still allowed to
 * show a pop-up: a listener cannot read another app's channels, but every
 * notification it receives carries its channel id, and the ranking that comes
 * with it carries the importance. Nothing here records what a notification
 * said — only which channel it arrived on.
 */
class PopupChannelStore(context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** One channel of one app, as last seen. */
    data class Entry(
        val packageName: String,
        val channelId: String,
        val importance: Int,
        val seenAtMs: Long,
    ) {
        /**
         * Whether this channel can interrupt with a pop-up.
         *
         * IMPORTANCE_HIGH is the level at which Android shows a heads-up; below
         * it the notification goes quietly to the shade, which is where Samir
         * Lock replaces it.
         */
        val canPopUp: Boolean get() = importance >= NotificationManager.IMPORTANCE_HIGH
    }

    fun record(packageName: String, channelId: String, importance: Int) {
        if (channelId.isEmpty()) return

        val existing = entries()
        val unchanged = existing.any {
            it.packageName == packageName &&
                it.channelId == channelId &&
                it.importance == importance
        }
        if (unchanged) return

        val updated = existing.filterNot {
            it.packageName == packageName && it.channelId == channelId
        } + Entry(packageName, channelId, importance, System.currentTimeMillis())

        write(updated)
        GuardLog.d(
            "popup: $packageName channel=$channelId importance=$importance " +
                "canPopUp=${importance >= NotificationManager.IMPORTANCE_HIGH}",
        )
    }

    fun entries(): List<Entry> {
        val raw = prefs.getString(KEY_CHANNELS, null) ?: return emptyList()

        return runCatching {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { index ->
                val item = array.optJSONObject(index) ?: return@mapNotNull null
                Entry(
                    packageName = item.optString(FIELD_PACKAGE),
                    channelId = item.optString(FIELD_CHANNEL),
                    importance = item.optInt(FIELD_IMPORTANCE, -1),
                    seenAtMs = item.optLong(FIELD_SEEN_AT, 0L),
                )
            }.filter { it.packageName.isNotEmpty() && it.channelId.isNotEmpty() }
        }.getOrElse {
            GuardLog.w("popup: could not read stored channels", it)
            emptyList()
        }
    }

    /** Channels of [lockedPackages] that can still show a pop-up. */
    fun popupWarnings(lockedPackages: Set<String>): List<Entry> =
        entries().filter { it.packageName in lockedPackages && it.canPopUp }

    /** Drops everything remembered about a package. */
    fun forget(packageName: String) {
        write(entries().filterNot { it.packageName == packageName })
    }

    private fun write(entries: List<Entry>) {
        val array = JSONArray()
        for (entry in entries) {
            array.put(
                JSONObject()
                    .put(FIELD_PACKAGE, entry.packageName)
                    .put(FIELD_CHANNEL, entry.channelId)
                    .put(FIELD_IMPORTANCE, entry.importance)
                    .put(FIELD_SEEN_AT, entry.seenAtMs),
            )
        }
        prefs.edit().putString(KEY_CHANNELS, array.toString()).apply()
    }

    private companion object {
        const val PREFS_NAME = "samir_lock_preferences"
        const val KEY_CHANNELS = "popup_channels"

        const val FIELD_PACKAGE = "pkg"
        const val FIELD_CHANNEL = "channel"
        const val FIELD_IMPORTANCE = "importance"
        const val FIELD_SEEN_AT = "seenAt"
    }
}
