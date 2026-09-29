package com.samirlock.app.bridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.samirlock.app.data.LockedAppsStore
import com.samirlock.app.inventory.InstalledAppsProvider
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
 */
class SamirLockBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val appsProvider = InstalledAppsProvider(context)
    private val lockedAppsStore = LockedAppsStore(context)
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var executor: ExecutorService? = null

    fun attach() {
        executor = Executors.newSingleThreadExecutor()
        channel.setMethodCallHandler(this)
    }

    fun detach() {
        channel.setMethodCallHandler(null)
        executor?.shutdownNow()
        executor = null
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
                runInBackground(result) { lockedAppsStore.setLocked(packageName, locked) }
            }

            else -> result.notImplemented()
        }
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

        const val ARG_PACKAGE_NAME = "packageName"
        const val ARG_LOCKED = "locked"

        const val ERROR_INVALID_ARGUMENTS = "invalid_arguments"
        const val ERROR_NATIVE_FAILURE = "native_failure"
        const val ERROR_UNAVAILABLE = "bridge_unavailable"
    }
}
