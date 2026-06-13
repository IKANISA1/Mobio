# Device UAT Attempt - 2026-06-12

## Target

- Device: Pixel 4a
- Serial: `13111JEC215558`
- Android: 13
- Package: `rw.mobi.app`
- Activity: `rw.mobi.app/.MainActivity`
- Installed build: versionCode `14`, versionName `1.0.0`

## Intended UAT Scope

- Launch stability and first-screen visual proof.
- WhatsApp Cloud OTP login:
  - passenger send OTP
  - passenger verify OTP
  - driver send OTP
  - invalid/expired code handling where safe
  - resend/rate-limit behavior where safe
- Authenticated app shell:
  - home
  - trips/bookings
  - schedule trip
  - trip details
  - edit/cancel own trip where safe
  - nearby trips
  - chat handoff from trip where safe
  - profile and driver profile details
  - notification surfaces
- Safe-area, scroll, keyboard, and transition checks with screenshots/logcat.

## What Was Confirmed

- macOS initially detected the Pixel 4a over USB.
- ADB briefly authorized the device as `device`.
- Installed package metadata was captured before the connection dropped.
- Launch intent resolved to `rw.mobi.app/.MainActivity`.
- Later retry on 2026-06-12 confirmed the Pixel 4a was online again:
  `13111JEC215558 device usb:20-2.4 product:sunfish model:Pixel_4a`.
- Installed package metadata at initial retry showed `rw.mobi.app` versionCode
  `14`, versionName `1.0.0`, last updated `2026-06-12 16:42:36`.
- Two release APK rebuild attempts initially reached post tree-shaking
  packaging and then stalled without producing `app-release.apk`:
  - first attempt: `assembleRelease` interrupted after `286.3s`;
  - second attempt with `ANDROID_RELEASE_SHRINK=false`: interrupted after
    `184.9s`.
- Root cause found: direct Gradle under shell-default Java `25.0.1` fails with
  Kotlin `JavaVersion.parse` error. Rebuilding with Java 17 fixed the build.
- Fresh release APK was built with:
  `JAVA_HOME=/usr/local/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home ANDROID_RELEASE_SHRINK=false ANDROID_BUILD_NUMBER=15 scripts/release/build_android_release.sh apk`.
- Fresh APK installed successfully with `adb -s 13111JEC215558 install -r`.
- Current installed package metadata:
  - versionCode `15`
  - versionName `1.0.0`
  - lastUpdateTime `2026-06-12 18:20:04`
- Current launch attempt delivered to `rw.mobi.app/.MainActivity`; Android
  window state showed the app as the focused app behind the lock screen.

## Blocker

Current-code device UAT is blocked by the Pixel PIN lock screen.

Earlier in the day, ADB disconnected during first screenshot/UI-tree capture
after launch.

The generated `01-launch.png` and `01-launch.xml` files are empty because the
device disappeared before `screencap` and `uiautomator dump` could complete.
Subsequent polling later recovered the device, and the latest Flutter client is
now installed, but `03-after-unlock-launch.xml` shows Android requesting
`Enter your PIN`. UAT cannot proceed without a human unlocking the device.

## Required To Resume

Unlock the Pixel 4a manually, keep it connected, and leave it on the app. The
expected ready ADB state is:

```text
13111JEC215558 device
```

If USB becomes unstable again, run:

```bash
adb -s 13111JEC215558 tcpip 5555
```

Then continue UAT from this evidence folder. For the OTP verification step, the
human tester must provide the received WhatsApp OTP code unless the device
already has a valid authenticated session.

Resume capture command after manual unlock:

```bash
ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_STEP=06-unlocked-otp-start \
scripts/qa/capture_android_uat_state.sh
```

The script exits `2` if the device is still locked, and it does not enter PINs
or OTP codes.

Latest repeated check:

```bash
ANDROID_SERIAL=13111JEC215558 \
ANDROID_UAT_STEP=06-goal-resume-lock-check \
scripts/qa/capture_android_uat_state.sh
```

Result: exited `2`; device still locked with `NotificationShade` focused and
`rw.mobi.app/.MainActivity` behind the lock screen. Evidence files are named
`06-goal-resume-lock-check*` in this folder.

## Unlocked Device Continuation

After the Pixel 4a was manually unlocked, UAT resumed against the WhatsApp
login screen.

Confirmed:

- Android window focus: `rw.mobi.app/.MainActivity`.
- Global country-code picker opened and searched successfully.
- Country picker search for `Malta` returned `Malta +356`.
- Selecting the result changed the login input prefix to `+356`.
- A false `No internet connection` banner was visible even while Android
  reported validated Wi-Fi and shell ping succeeded.

Root cause:

- `ConnectivityOverlay` treated an empty `connectivity_plus` result list as
  offline because `Iterable.every` returns `true` for an empty list.
- The overlay had no debounce, so transient Android startup/resume connectivity
  events could show an offline banner immediately.
- The UAT capture script also treated any `NotificationShade` window entry as
  a lock-screen signal, which is not reliable on an unlocked focused app.

Fix installed:

- APK versionCode `16`, versionName `1.0.0`.
- APK SHA-256:
  `7d0d5eebb48c3379cf1de4f1479b5dabd8e77e88785fe9015b737366eefea064`.
- `ConnectivityOverlay` now treats empty connectivity results as unknown,
  debounces real offline state, and only renders the banner while offline.
- `capture_android_uat_state.sh` no longer uses `NotificationShade` as a lock
  signal.

Post-fix device proof:

- Evidence prefix: `11-connectivity-overlay-fixed*`.
- Screenshot: `11-connectivity-overlay-fixed.png`.
- UI tree: `11-connectivity-overlay-fixed.xml`.
- Summary: `11-connectivity-overlay-fixed-summary.txt`.
- Result: no `No internet connection` node was present in the UI tree, and the
  screenshot showed no app offline banner.
- Device network state still reported active default Wi-Fi network `348` with
  `VALIDATED` capability.

Remaining UAT:

- Real WhatsApp OTP send/verify still requires an approved recipient phone and
  human-provided OTP code.
- Authenticated trips/home/profile flows still require completing OTP or using
  an existing valid session.
