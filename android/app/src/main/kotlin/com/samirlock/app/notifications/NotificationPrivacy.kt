package com.samirlock.app.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import com.samirlock.app.R
import com.samirlock.app.guard.GuardLog

/**
 * Helpers for the notification privacy feature.
 *
 * Notification access is granted in a Settings screen of its own, separate from
 * the permissions Samir Lock asks for during setup, because this feature is
 * optional and off unless the user turns it on.
 */
object NotificationPrivacy {

    private const val CHANNEL_ID = "samir_lock_hidden_notifications"

    /** Placeholder ids are derived from the package, so each app keeps one. */
    fun notificationIdFor(packageName: String): Int = packageName.hashCode()

    /**
     * Whether the user has given Samir Lock notification access.
     *
     * Read from the secure setting rather than through a support library, which
     * keeps this dependency free and works on every version.
     */
    fun hasAccess(context: Context): Boolean {
        val enabled = runCatching {
            Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            )
        }.getOrNull() ?: return false

        val target = ComponentName(context, NotificationPrivacyService::class.java)
        return enabled.split(':').any { entry ->
            val component = ComponentName.unflattenFromString(entry)
            component != null && component.packageName == target.packageName
        }
    }

    /** Opens the Android screen where notification access is granted. */
    fun openAccessSettings(context: Context, fromActivity: Boolean): Boolean {
        val candidates = listOf(
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
            Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"),
            Intent(Settings.ACTION_SETTINGS),
        )

        for (intent in candidates) {
            if (!fromActivity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(context.packageManager) == null) continue
            if (runCatching { context.startActivity(intent) }.isSuccess) return true
        }
        return false
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.privacy_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = context.getString(R.string.privacy_channel_description)
                setShowBadge(true)
                // The original app already made its sound; this replacement
                // should not make a second one.
                setSound(null, null)
                enableVibration(false)
            },
        )
    }

    /**
     * Builds the stand-in shown in place of a hidden notification.
     *
     * It carries the original's tap action, so opening it goes to the app just
     * as the real notification would — and the guard then asks for the PIN. The
     * title, text, sender, image and actions of the original are all dropped.
     */
    fun buildPlaceholder(
        context: Context,
        appName: String,
        count: Int,
        originalIntent: PendingIntent?,
    ): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val text = if (count > 1) {
            context.getString(R.string.privacy_hidden_many, count)
        } else {
            context.getString(R.string.privacy_hidden_one)
        }

        return builder
            .setSmallIcon(R.drawable.ic_guard_shield)
            .setContentTitle(appName)
            .setContentText(text)
            .setAutoCancel(true)
            // Safe to show on the lock screen: the title is the app's own name
            // and the text is a fixed string of ours. Nothing from the original
            // notification is in here. Hiding it entirely would leave the user
            // with no sign that anything arrived.
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .apply { originalIntent?.let(::setContentIntent) }
            .build()
    }

    fun cancelPlaceholder(context: Context, packageName: String) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        runCatching { manager.cancel(notificationIdFor(packageName)) }
            .onFailure { GuardLog.w("privacy: could not clear placeholder", it) }
    }
}
