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
| Version | 1.0.0 (build 1) — from `pubspec.yaml` |
| Category suggestion | Utilities / Productivity |
| Platforms | iOS 13+, Android 7.0+ (API 24+) |

## Blocking — cannot submit without these

These need action from you (Apple Developer / Google Play Console access,
or a judgment call I shouldn't make unilaterally) before either store will
accept a build.

- [ ] **iOS distribution signing.** Currently only signs with your local
  Apple Development certificate (fine for `flutter run`, not for App Store
  Connect). In Xcode: Signing & Capabilities → enable "Automatically manage
  signing" with your paid Apple Developer account, or generate a
  Distribution certificate + App Store provisioning profile manually.
- [ ] **Android release signing.** `android/app/build.gradle.kts` still signs
  the `release` build type with the debug keystore (see the `// TODO: Add
  your own signing config` comment). You need to:
  1. `keytool -genkey -v -keystore ~/khsae-tei-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias khsae_tei`
  2. Create `android/key.properties` (already gitignored) with the keystore
     path/passwords.
  3. Wire a real `signingConfigs.release` block referencing it.
  **Back up that keystore file + passwords somewhere durable — losing it
  means you can never update the app under this listing again.**
- [ ] **Privacy policy hosted at a public URL.** Both stores require one
  because the app requests camera/local-network access. Draft text is below
  — host it anywhere (GitHub Pages, a gist rendered as a page, a simple
  static site) and give me the URL to drop into the store listing metadata
  below.

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
> **Contact:** [fill in a contact email]

## App Store / Play Console questionnaire answers

- **Does the app collect user data?** No.
- **Does the app share data with third parties?** No.
- **Does the app use encryption?** No custom/non-exempt encryption
  (`ITSAppUsesNonExemptEncryption` is set to `false`).
- **Data Safety form (Play Console):** No data collected, no data shared.
- **Target audience / content rating:** General audience, no
  user-generated content, no ads.
- **Advertising ID usage:** Not used.

## Screenshots

Captured from the iPhone 17 Pro simulator (iOS 26.5, 1206×2622) with the
debug banner suppressed. Both screens now share the same dark/cosmic theme
(`lib/theme.dart`, `lib/widgets.dart`):

- `store_assets/screenshots/01_home.png` — Home dashboard
- `store_assets/screenshots/02_settings.png` — Settings (connection setup)

**Before using these as final store assets:** Apple and Google both require
specific pixel dimensions per device class, and those requirements shift
over time — check the current list in App Store Connect / Play Console at
upload time and re-capture at the exact required sizes if these don't
match.

## Final pre-submission checklist

- [ ] Resolve the two blocking signing items above
- [ ] Host the privacy policy, get a URL, fill in date + contact email
- [ ] Re-capture screenshots at the exact sizes each store currently requires
- [ ] `flutter build appbundle --release` (Android) and an Xcode Archive
  (iOS) — neither has been run in this environment (no Android SDK
  installed here, and iOS release archiving needs a Distribution
  certificate that doesn't exist yet)
- [ ] Run `pod install` in `mobile/ios/` on a Mac before the next iOS build
  — `Podfile.lock` still references `flutter_background_service_ios` and
  other now-removed pods; it can only be regenerated with CocoaPods on
  macOS, not from this environment
- [ ] Bump `version:` in `pubspec.yaml` if this isn't truly `1.0.0+1`
