# Samir Lock R8 rules.
#
# Most of the app is reached from the manifest, which R8 already understands.
# These rules cover the parts it cannot see, and keep the lock engine readable
# in a crash report.

# Components named in AndroidManifest.xml. Keeping them explicitly means a
# renamed or removed class can never silently break locking on a release build.
-keep class com.samirlock.app.MainActivity { *; }
-keep class com.samirlock.app.lock.LockActivity { *; }
-keep class com.samirlock.app.lock.PinSetupActivity { *; }
-keep class com.samirlock.app.guard.GuardService { *; }
-keep class com.samirlock.app.guard.BootReceiver { *; }
-keep class com.samirlock.app.guard.GuardWatchdogReceiver { *; }

# Shared process-wide state between the service and the lock screen.
-keep class com.samirlock.app.guard.LockCoordinator { *; }
-keep class com.samirlock.app.lock.LockShield { *; }

# AndroidX BiometricPrompt resolves fragments and callbacks reflectively.
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Keep line numbers so a stack trace from a release build is worth reading.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
