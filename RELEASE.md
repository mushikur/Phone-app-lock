# Releasing Samir Lock

What is ready, and what only you can do.

## Done in the project

- `applicationId` / namespace: `com.samirlock.app`
- `minSdk 24`, `targetSdk 36`, `compileSdk 36`, pinned explicitly rather than
  following the Flutter SDK
- Release build shrinks and obfuscates with R8 (`isMinifyEnabled`,
  `isShrinkResources`) using `android/app/proguard-rules.pro`
- Launcher icon: adaptive (with a monochrome layer for themed icons) plus legacy
  and round PNGs for every density
- Release signing reads `android/key.properties`, which is gitignored
- Debug logging is compiled in but only emits on a debuggable build, so a
  release build writes nothing about the user's apps to logcat
- Unused iOS / macOS / Web / Windows / Linux scaffolds removed

## What you must do before publishing

### 1. Create a keystore

Losing this file or its passwords means you can never update the app on Google
Play again. Back both up somewhere safe and private.

```bash
keytool -genkey -v -keystore samir-lock-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias samir-lock
```

Copy `android/key.properties.example` to `android/key.properties` and fill it
in. Until you do, release builds fall back to the debug key and print a warning
— such a build must never be published.

### 2. Build

```bash
flutter build appbundle --release
```

Google Play wants the `.aab`. Use `flutter build apk --release` only for
sideloading and testing.

### 3. Play Console declarations

Two things on this app need an explicit justification, and reviewers do reject
weak answers.

**Foreground service type `specialUse`.** Declare it as: *Samir Lock watches
which app is in the foreground so it can show its lock screen before a protected
app becomes usable. This must continue while the user is inside other apps, so
it cannot be done from the background or with a deferred job.*

**`SYSTEM_ALERT_WINDOW` (Display over other apps).** Needed to place the lock
screen over the app being opened; it is also the only reason Android permits the
lock screen to be started from the background at all.

`PACKAGE_USAGE_STATS` is a special access the user grants in Settings and needs
no Play declaration. The app deliberately does **not** use
`QUERY_ALL_PACKAGES`: it discovers launchable apps through a `<queries>` entry
instead, which avoids that declaration entirely.

### 4. Data safety form

Samir Lock collects nothing and transmits nothing:

| Question | Answer |
|---|---|
| Does your app collect or share user data? | No |
| Is data encrypted in transit? | Not applicable, no data leaves the device |
| Can users request data deletion? | Not applicable, nothing is collected |

Worth stating in the listing: the PIN is stored only as a PBKDF2 hash sealed
with an Android Keystore key, and the app has no internet permission at all.

### 5. Test the release build, not just the debug one

R8 can remove or rename something the manifest needs. Before every release:

- install the release APK and confirm a locked app still shows the lock screen
- confirm the PIN and fingerprint both unlock
- reboot and confirm protection comes back without opening the app
- confirm the release APK's permission list still has no `INTERNET`

## Known limitations to keep in mind

- Detection polls `UsageStatsManager`, so there is a short delay between a
  protected app appearing and the lock covering it. The shield overlay hides that
  gap; the delay itself cannot be removed without an `AccessibilityService`.
- OEM battery managers, One UI included, will eventually stop the guard. The
  boot receiver, the watchdog alarm and the restart-on-status-read recover it,
  but the user should still add Samir Lock to "Never sleeping apps".
- If the user revokes "Display over other apps", the lock screen cannot be shown
  at all. The guard notices and stops, so the app reports that it cannot protect
  rather than appearing to.
