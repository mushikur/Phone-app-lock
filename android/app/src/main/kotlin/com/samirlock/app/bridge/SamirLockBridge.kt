package com.samirlock.app.bridge

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import com.samirlock.app.auth.BiometricAuthenticator
import com.samirlock.app.auth.LockoutPolicy
import com.samirlock.app.auth.LockoutStore
import com.samirlock.app.auth.PinVault
import com.samirlock.app.data.LockedAppsStore
import com.samirlock.app.lock.PinSetupActivity
import com.samirlock.app.notifications.NotificationPrivacy
import com.samirlock.app.guard.GuardLog
import com.samirlock.app.guard.GuardPreferences
import com.samirlock.app.guard.GuardServiceController
import com.samirlock.app.inventory.InstalledAppsProvider
import com.samirlock.app.permissions.PermissionChecker
import com.samirlock.app.permissions.PermissionIds
import com.samirlock.app.permissions.PermissionSettingsLauncher
import com.samirlock.app.permissions.PermissionStatuses
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Single MethodChannel between the Flutter UI layer and the Android native layer.
 *
 * Work that touches the package manager runs on a background executor; results are
 * always delivered back on the platform thread, as MethodChannel requires.
 * Permission checks are cheap and stay on the platform thread, and the ones that
 * need a window — settings pages and the notification prompt — go through
 * [activity], which the hosting Activity binds and clears.
 */
class SamirLockBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val appsProvider = InstalledAppsProvider(context)
    private val lockedAppsStore = LockedAppsStore(context)
    private val permissionChecker = PermissionChecker(context)
    private val settingsLauncher = PermissionSettingsLauncher(context)
    private val guardPreferences = GuardPreferences(context)
    private val pinVault = PinVault(context)
    private val lockoutStore = LockoutStore(context)
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var executor: ExecutorService? = null

    /** Set while an Activity is hosting the Flutter engine. */
    var activity: Activity? = null

    /** Reply waiting on the POST_NOTIFICATIONS system prompt, if any. */
    private var pendingNotificationResult: MethodChannel.Result? = null

    fun attach() {
        GuardLog.configure(appContext)
        // The service does not survive the process being killed, but the user's
        // choice does; bring the guard back up before the UI asks about it.
        GuardServiceController.startIfEnabled(appContext)
        executor = Executors.newSingleThreadExecutor()
        channel.setMethodCallHandler(this)
    }

    fun detach() {
        channel.setMethodCallHandler(null)
        executor?.shutdownNow()
        executor = null
        pendingNotificationResult = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_GET_INSTALLED_APPS -> runInBackground(result) { appsProvider.loadInstalledApps() }
            METHOD_GET_LOCKED_PACKAGES -> runInBackground(result) {
                lockedAppsStore.lockedPackages().toList()
            }

            METHOD_SET_APP_LOCKED -> {
                val packageName = call.argument<String>(ARG_PACKAGE_NAME)
                val locked = call.argument<Boolean>(ARG_LOCKED)
                if (packageName.isNullOrEmpty() || locked == null) {
                    result.error(
                        ERROR_INVALID_ARGUMENTS,
                        "setAppLocked requires a packageName and a locked flag.",
                        null,
                    )
                    return
                }
                runInBackground(result) {
                    val state = lockedAppsStore.setLocked(packageName, locked)
                    GuardLog.d(
                        "bridge: setAppLocked $packageName=$locked, " +
                            "locked now ${lockedAppsStore.lockedPackages()}",
                    )
                    state
                }
            }

            METHOD_GET_PERMISSION_STATUSES -> result.success(permissionChecker.snapshot())

            METHOD_OPEN_PERMISSION_SETTINGS -> {
                val permissionId = call.argument<String>(ARG_PERMISSION)
                if (permissionId.isNullOrEmpty() || permissionId !in PermissionIds.all) {
                    result.error(
                        ERROR_INVALID_ARGUMENTS,
                        "openPermissionSettings requires a known permission id.",
                        null,
                    )
                    return
                }
                result.success(settingsLauncher.open(permissionId, activity))
            }

            METHOD_REQUEST_NOTIFICATION_PERMISSION -> requestNotificationPermission(result)

            METHOD_GET_PROTECTION_STATUS -> result.success(protectionStatus())

            METHOD_GET_SECURITY_STATUS -> result.success(securityStatus())

            METHOD_SET_NOTIFICATION_PRIVACY -> {
                val enabled = call.argument<Boolean>(ARG_ENABLED)
                if (enabled == null) {
                    result.error(
                        ERROR_INVALID_ARGUMENTS,
                        "setNotificationPrivacyEnabled requires an enabled flag.",
                        null,
                    )
                    return
                }
                // Turning it on without notification access would silently do
                // nothing, so the preference only sticks when it can work.
                val granted = NotificationPrivacy.hasAccess(appContext)
                guardPreferences.isNotificationPrivacyEnabled = enabled && granted
                GuardLog.d("bridge: setNotificationPrivacyEnabled($enabled) access=$granted")
                result.success(securityStatus())
            }

            METHOD_OPEN_NOTIFICATION_ACCESS -> {
                val host = activity
                val opened = NotificationPrivacy.openAccessSettings(
                    context = host ?: appContext,
                    fromActivity = host != null,
                )
                result.success(opened)
            }

            METHOD_SET_BIOMETRIC_ENABLED -> {
                val enabled = call.argument<Boolean>(ARG_ENABLED)
                if (enabled == null) {
                    result.error(
                        ERROR_INVALID_ARGUMENTS,
                        "setBiometricEnabled requires an enabled flag.",
                        null,
                    )
                    return
                }
                guardPreferences.isBiometricEnabled = enabled
                GuardLog.d("bridge: setBiometricEnabled($enabled)")
                result.success(securityStatus())
            }

            METHOD_OPEN_PIN_SETUP -> {
                val host = activity
                if (host == null) {
                    result.error(
                        ERROR_NO_ACTIVITY,
                        "PIN setup needs a foreground window.",
                        null,
                    )
                    return
                }
                // The PIN is typed natively; nothing about it comes back here.
                val opened = runCatching {
                    host.startActivity(Intent(host, PinSetupActivity::class.java))
                }.isSuccess
                result.success(opened)
            }

            METHOD_SET_PROTECTION_ENABLED -> {
                val enabled = call.argument<Boolean>(ARG_ENABLED)
                if (enabled == null) {
                    result.error(
                        ERROR_INVALID_ARGUMENTS,
                        "setProtectionEnabled requires an enabled flag.",
                        null,
                    )
                    return
                }
                result.success(setProtectionEnabled(enabled))
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Shows the POST_NOTIFICATIONS prompt where it exists, replying with the
     * resulting status. On older Android versions there is no prompt, so the
     * current status is returned unchanged and the UI falls back to Settings.
     */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        val currentStatus = permissionChecker.status(PermissionIds.NOTIFICATIONS)
        if (currentStatus == PermissionStatuses.GRANTED ||
            !permissionChecker.canRequestNotificationPermission()
        ) {
            result.success(currentStatus)
            return
        }

        val host = activity
        if (host == null) {
            result.error(
                ERROR_NO_ACTIVITY,
                "The notification prompt needs a foreground window.",
                null,
            )
            return
        }

        if (pendingNotificationResult != null) {
            result.error(
                ERROR_REQUEST_IN_PROGRESS,
                "A notification permission request is already in progress.",
                null,
            )
            return
        }

        pendingNotificationResult = result
        host.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_CODE_NOTIFICATIONS,
        )
    }

    /**
     * Forwarded from the hosting Activity.
     *
     * @return true when this bridge consumed the result.
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE_NOTIFICATIONS) return false

        val pending = pendingNotificationResult ?: return true
        pendingNotificationResult = null

        val index = permissions.indexOf(Manifest.permission.POST_NOTIFICATIONS)
        val granted = index >= 0 &&
            grantResults.size > index &&
            grantResults[index] == PackageManager.PERMISSION_GRANTED

        pending.success(
            if (granted) PermissionStatuses.GRANTED else PermissionStatuses.DENIED,
        )
        return true
    }

    /**
     * Whether protection is switched on, whether the service is actually up, and
     * whether the permissions it needs are in place.
     */
    private fun protectionStatus(): Map<String, Any?> {
        // Reading the status is also the moment to heal it: if protection is meant
        // to be on and the guard is down, start it rather than reporting a state
        // that is not true.
        GuardServiceController.startIfEnabled(appContext)

        val status = mapOf(
            KEY_ENABLED to guardPreferences.isProtectionEnabled,
            KEY_RUNNING to GuardServiceController.isRunning(),
            KEY_CAN_RUN to GuardServiceController.canRun(appContext),
            KEY_HAS_PIN to pinVault.hasPin(),
        )
        GuardLog.d("bridge: protection status $status")
        return status
    }

    /**
     * Starts or stops the guard and remembers the choice.
     *
     * Enabling fails silently-but-visibly when the required permissions are
     * missing: the returned status simply still says disabled, and the UI reports
     * what is missing rather than showing protection as on when it is not.
     */
    /**
     * What the Flutter layer is allowed to know about authentication: whether a
     * PIN exists and whether biometrics are usable. Never the PIN, never the
     * stored record, and nothing that could release a lock.
     */
    private fun securityStatus(): Map<String, Any?> = mapOf(
        KEY_HAS_PIN to pinVault.hasPin(),
        KEY_BIOMETRIC to BiometricAuthenticator.availabilityOf(appContext).name,
        KEY_BIOMETRIC_ENABLED to guardPreferences.isBiometricEnabled,
        // Enough to describe the lockout to the user, and nothing that could help
        // anyone past it.
        KEY_FREE_ATTEMPTS to LockoutPolicy.FREE_ATTEMPTS,
        KEY_FAILED_ATTEMPTS to lockoutStore.failedAttempts,
        KEY_NOTIFICATION_PRIVACY to guardPreferences.isNotificationPrivacyEnabled,
        KEY_NOTIFICATION_ACCESS to NotificationPrivacy.hasAccess(appContext),
    )

    private fun setProtectionEnabled(enabled: Boolean): Map<String, Any?> {
        GuardLog.d("bridge: setProtectionEnabled($enabled)")
        if (!enabled) {
            GuardServiceController.stop(appContext)
            guardPreferences.isProtectionEnabled = false
            return protectionStatus()
        }

        // Without a PIN the lock screen has nothing to authenticate against, so
        // protection must not claim to be on.
        if (!pinVault.hasPin()) {
            GuardLog.w("bridge: refusing to enable protection, no PIN set")
            guardPreferences.isProtectionEnabled = false
            return protectionStatus()
        }

        val started = GuardServiceController.start(appContext)
        guardPreferences.isProtectionEnabled = started
        return protectionStatus()
    }

    private fun runInBackground(result: MethodChannel.Result, work: () -> Any?) {
        val runner = executor
        if (runner == null || runner.isShutdown) {
            result.error(ERROR_UNAVAILABLE, "The native bridge is no longer attached.", null)
            return
        }
        runner.execute {
            val outcome = runCatching(work)
            mainHandler.post {
                outcome
                    .onSuccess { result.success(it) }
                    .onFailure { result.error(ERROR_NATIVE_FAILURE, it.message, null) }
            }
        }
    }

    private companion object {
        const val CHANNEL_NAME = "com.samirlock.app/bridge"

        const val METHOD_GET_INSTALLED_APPS = "getInstalledApps"
        const val METHOD_GET_LOCKED_PACKAGES = "getLockedPackages"
        const val METHOD_SET_APP_LOCKED = "setAppLocked"
        const val METHOD_GET_PERMISSION_STATUSES = "getPermissionStatuses"
        const val METHOD_OPEN_PERMISSION_SETTINGS = "openPermissionSettings"
        const val METHOD_REQUEST_NOTIFICATION_PERMISSION = "requestNotificationPermission"
        const val METHOD_GET_PROTECTION_STATUS = "getProtectionStatus"
        const val METHOD_SET_PROTECTION_ENABLED = "setProtectionEnabled"
        const val METHOD_GET_SECURITY_STATUS = "getSecurityStatus"
        const val METHOD_OPEN_PIN_SETUP = "openPinSetup"
        const val METHOD_SET_BIOMETRIC_ENABLED = "setBiometricEnabled"
        const val METHOD_SET_NOTIFICATION_PRIVACY = "setNotificationPrivacyEnabled"
        const val METHOD_OPEN_NOTIFICATION_ACCESS = "openNotificationAccess"

        const val ARG_PACKAGE_NAME = "packageName"
        const val ARG_LOCKED = "locked"
        const val ARG_PERMISSION = "permission"
        const val ARG_ENABLED = "enabled"

        const val KEY_ENABLED = "enabled"
        const val KEY_RUNNING = "running"
        const val KEY_CAN_RUN = "canRun"
        const val KEY_HAS_PIN = "hasPin"
        const val KEY_BIOMETRIC = "biometric"
        const val KEY_BIOMETRIC_ENABLED = "biometricEnabled"
        const val KEY_FREE_ATTEMPTS = "freeAttempts"
        const val KEY_FAILED_ATTEMPTS = "failedAttempts"
        const val KEY_NOTIFICATION_PRIVACY = "notificationPrivacyEnabled"
        const val KEY_NOTIFICATION_ACCESS = "notificationAccessGranted"

        const val ERROR_INVALID_ARGUMENTS = "invalid_arguments"
        const val ERROR_NATIVE_FAILURE = "native_failure"
        const val ERROR_UNAVAILABLE = "bridge_unavailable"
        const val ERROR_NO_ACTIVITY = "no_activity"
        const val ERROR_REQUEST_IN_PROGRESS = "request_in_progress"

        const val REQUEST_CODE_NOTIFICATIONS = 4801
    }
}
