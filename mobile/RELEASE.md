# KHSAE TEI — Release Readiness

Everything needed to submit the mobile app to the App Store and Google Play:
what's done, what's still blocking, draft store-listing copy, a privacy
policy draft, and answers to the review questionnaires both stores ask.
Screenshots are in [`store_assets/screenshots/`](store_assets/screenshots/).

## App identity

| | |
|---|---|
| Display name | ខ្សែតី KHSAE TEI |
| iOS bundle ID | `com.khsaetei.khsaeTei` |
| Android application ID | `com.khsaetei.khsae_tei` |
| Version | 1.0.0 (build 2) — from `pubspec.yaml` |
| Category suggestion | Utilities / Productivity |
| Platforms | iOS 13+, Android 7.0+ (API 24+) |

## Blocking — Android status (2026-08-10)

Android release-prep is now done end-to-end from this environment. What
changed:

- [x] **Android release signing.** Generated a real upload keystore
  (`~/khsae-tei-release/khsae-tei-upload.jks`, valid until 2053, **not** in
  this repo). `android/key.properties` (gitignored) holds the alias and
  passwords; `android/app/build.gradle.kts` now loads it and signs `release`
  with `signingConfigs.getByName("release")` instead of the debug key —
  verified with `apksigner verify --print-certs` against the built APK.
  **The passwords were shown once in chat when generated — make sure you
  saved `~/khsae-tei-release/upload-keystore-password.txt` and the `.jks`
  itself somewhere durable (password manager + backup). Losing either means
  you can never update this app under this Play listing again.**
- [x] **Minification/shrinking enabled** for release (`isMinifyEnabled`,
  `isShrinkResources`, `android/app/proguard-rules.pro` with keep rules for
  the ML Kit barcode scanner `mobile_scanner` depends on). Verified on a
  real device (Galaxy Note20): app launched, QR-scan-to-pair actually scanned
  the desktop's live QR code and paired successfully, Test Whip worked — no
  regressions from shrinking.
- [x] **Privacy policy** — finalized (date + contact email filled in) and
  added at `docs/privacy-policy.html`, ready for GitHub Pages. **One manual
  step left for you**: repo Settings → Pages → Source: "Deploy from a
  branch" → `main` / `/docs`. Once enabled the URL will be
  `https://rathanaksreang.github.io/khsae_tei/privacy-policy.html` — use
  that in the Play Console privacy policy field.
- [x] **Store assets generated**: `store_assets/icon_512.png` (hi-res
  console icon), `store_assets/feature_graphic.png` (1024×500), and real
  Android screenshots (1080×2400, captured on the Note20) replacing the old
  iOS-simulator ones at `store_assets/screenshots/`.
- [x] **`flutter build appbundle --release`** succeeds and produces
  `build/app/outputs/bundle/release/app-release.aab` — this is the file to
  upload to Play Console.

Still open (only you can do these — no Play Console/Google account access
from here):

- [ ] Create/confirm a Google Play Developer account ($25 one-time).
- [ ] Create the app entry in Play Console and upload the `.aab`.
- [ ] Flip the GitHub Pages toggle (one click, see above).
- [ ] Paste in the store listing text/assets below and answer the
  questionnaires (answers already drafted below).
- [ ] **Exclude tablets** — this app has no tablet-adapted layout (phone
  gesture app, no orientation/screen-size handling). No tablet screenshots
  were produced (no tablet/tablet emulator available in this environment).
  In Play Console: Release → Setup → Advanced settings → **Device catalog**
  → add an exclusion rule for form factor "Tablet". This removes the
  tablet screenshot requirement from the listing and stops the app being
  offered to tablet users.
- [ ] **iOS remains untouched** — distribution signing still needs a paid
  Apple Developer account + Xcode on a Mac; not attempted here.

## Done

- [x] App icon + adaptive icon (Android) + all iOS sizes, generated from a
  clean source with no transparency defects — see `flutter_launcher_icons.yaml`
- [x] Splash screen, both platforms, rounded-corner branding — see
  `flutter_native_splash.yaml`
- [x] Localized display name (Khmer + English) on both platforms
- [x] `ITSAppUsesNonExemptEncryption: false` set in `Info.plist` (the app
  doesn't implement custom encryption — plain `ws://` on the LAN — so this
  skips Apple's export-compliance prompt on every upload)
- [x] `flutter analyze` clean, `flutter test` passing
- [x] Debug banner suppressed (`debugShowCheckedModeBanner: false`) so
  screenshots and demos don't show it
- [x] `compileSdk`/`targetSdk` 36, `minSdk` 24 — comfortably within Play's
  "target within one year of latest" policy

## Store listing draft

**Short description (Play Store, ≤80 chars):**
> Swing your phone like a whip to send Enter to your paired desktop.

**Full description draft:**
> KHSAE TEI (ខ្សែតី) is a "whip-app": swing your phone like a whip and it
> tells your paired desktop to press Enter — handy for approving a
> confirmation prompt without reaching for the keyboard.
>
> - Detects a real whip-crack gesture via the accelerometer, no fumbling
>   with buttons
> - Pairs with your desktop over your local WiFi network with a one-time
>   pairing code
> - Scan a QR code or auto-discover the desktop on your network
> - No cloud, no accounts — the phone and desktop talk directly over your
>   own LAN
>
> Requires the companion KHSAE TEI desktop app running on your computer.

**Keywords (Play Store, comma-separated):** whip, remote control, gesture,
desktop remote, keyboard, productivity, accessibility, local network, LAN

**Release name** (Play Console → Production → Create release; internal
label, not shown to users):
> 1.0.0 (2) — Initial release

**Release notes** (Play Console → same screen; this one IS user-facing, on
the "What's new" section of the store listing — ≤500 chars per language):
> First release of KHSAE TEI.
>
> - Swing your phone like a whip to send Enter to your paired desktop
> - Pair over your local WiFi via QR code, auto-discovery, or manual entry
> - No cloud, no accounts — everything stays on your own network

## Privacy policy draft

Host this text anywhere public and use that URL for both stores' privacy
policy field.

> **Privacy Policy — KHSAE TEI**
> *Last updated: [fill in date]*
>
> KHSAE TEI does not collect, store, or transmit any personal data to us or
> to any third party. The app communicates directly with a companion
> desktop application over your local network only — nothing leaves your
> WiFi network.
>
> **Permissions we ask for, and why:**
> - **Camera** — to scan the QR code the desktop app displays for pairing.
>   Never used for anything else; no images are stored or transmitted.
> - **Local network access** — to discover the desktop app on your WiFi
>   network (mDNS) and connect to it.
>
> We do not use analytics, advertising, or crash-reporting SDKs. We do not
> have a server, a database, or an account system — there is nothing for us
> to collect.
>
> **Contact:** sreangrathanak@gmail.com

Hosted at [`docs/privacy-policy.html`](../docs/privacy-policy.html) —
public URL once GitHub Pages is enabled:
`https://rathanaksreang.github.io/khsae_tei/privacy-policy.html`.

## App Store / Play Console questionnaire answers

- **Does the app collect user data?** No.
- **Does the app share data with third parties?** No.
- **Does the app use encryption?** No custom/non-exempt encryption
  (`ITSAppUsesNonExemptEncryption` is set to `false`).
- **Data Safety form (Play Console):** No data collected, no data shared.
- **Target audience / content rating:** General audience, no
  user-generated content, no ads.
- **Advertising ID usage:** Not used.

## Screenshots (Android)

Re-captured 2026-08-10 on a real device (Samsung Galaxy Note20, Android 13,
1080×2400) with the debug banner suppressed, replacing the earlier
iOS-simulator captures. Both screens share the dark/cosmic theme
(`lib/theme.dart`, `lib/widgets.dart`):

- `store_assets/screenshots/01_home.png` — Home dashboard
- `store_assets/screenshots/02_settings.png` — Settings (connection setup)

1080×2400 is within Play Console's phone screenshot requirements (16:9–9:16
aspect ratio, min 320px). iOS screenshots still need re-capturing on an
actual iOS simulator/device before an App Store submission — out of scope
here (Android-only pass).

## Store assets (Android, Play Console)

- `store_assets/icon_512.png` — hi-res console icon (512×512)
- `store_assets/feature_graphic.png` — feature graphic (1024×500)
- `store_assets/screenshots/01_home.png`, `02_settings.png` — phone
  screenshots

## Final pre-submission checklist

Android:
- [x] Release signing, minification, privacy policy text/hosting, store
  assets, and `appbundle --release` build — all done, see above.
- [ ] Enable GitHub Pages (`main` / `/docs`) so the privacy policy URL goes
  live.
- [ ] Everything else is Play Console UI work: create the app, upload
  `build/app/outputs/bundle/release/app-release.aab`, paste in the listing
  text/assets above, answer the Data Safety + content rating
  questionnaires (answers above), submit.

iOS (untouched, no Mac available in this environment):
- [ ] iOS distribution signing (paid Apple Developer account + Xcode)
- [ ] Run `pod install` in `mobile/ios/` on a Mac — `Podfile.lock` still
  references removed pods and can only be regenerated with CocoaPods on
  macOS
- [ ] Re-capture iOS screenshots at current App Store Connect sizes
- [ ] Xcode Archive + upload

Both:
- [x] `version: 1.0.0+1` confirmed correct for a first release, no bump
  needed.
