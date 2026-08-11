# KHSAE TEI — Release Readiness

Everything needed to submit the mobile app to the App Store and Google Play:
what's done, what's still blocking, draft store-listing copy, a privacy
policy draft, and answers to the review questionnaires both stores ask.
Screenshots are in [`store_assets/screenshots/`](store_assets/screenshots/).

## App identity

| | |
|---|---|
| Display name | ខ្សែតី KHSAE TEI |
| iOS bundle ID | `com.khsaetei.app` (team `7PSLDSBLKA`, "Socheat Leng") |
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
## Blocking — iOS status (2026-08-11)

iOS distribution signing is now set up and a signed, App Store-ready build
exists. What changed:

- [x] **Bundle ID changed to `com.khsaetei.app`** (was
  `com.khsaetei.khsaeTei`) — this matches the distribution certificate and
  provisioning profile that were already generated for this app under Apple
  Developer team `7PSLDSBLKA` ("Socheat Leng"). Updated everywhere: the
  `Runner` target and the `RunnerTests` target (now
  `com.khsaetei.app.RunnerTests`) in `Runner.xcodeproj/project.pbxproj`, and
  this doc. **If `com.khsaetei.khsaeTei` was already used to create an app
  record in App Store Connect, that record won't match — either create a new
  App Store Connect app under `com.khsaetei.app`, or tell me and I'll switch
  the bundle ID back and get a matching cert/profile issued instead.**
- [x] **Manual signing configured** — `CODE_SIGN_STYLE = Manual`,
  `DEVELOPMENT_TEAM = 7PSLDSBLKA`, provisioning profile specifier `"KHSAE
  TEI"`, certificate `iPhone Distribution: Socheat Leng (7PSLDSBLKA)`. Both
  the certificate and a matching provisioning profile were already present
  in this Mac's keychain/Xcode. Found and removed a **stale duplicate**
  provisioning profile also named "KHSAE TEI" (an older one tied to a
  different, non-matching distribution certificate) that was causing Xcode
  to pick the wrong profile on export — only the current, matching one
  remains installed now.
- [x] **`flutter build ipa --release --export-method app-store` succeeds**
  and produces a correctly signed `build/ios/ipa/khsae_tei.ipa` (29.8MB,
  verified with `codesign -dv`: team `7PSLDSBLKA`, chains to Apple Root CA).
  This is the file to upload.
- [x] **CocoaPods already resolved** — `ios/Pods` exists and `Podfile.lock`
  is in sync; the "run `pod install` on a Mac" blocker from the previous
  pass is no longer applicable.
- [x] **Restricted to iPhone only** (`TARGETED_DEVICE_FAMILY = "1"`, was
  `"1,2"`) — mirrors the Android tablet exclusion above (no
  iPad-adapted layout) and avoids App Store Connect requiring iPad
  screenshots.
- [x] **One iOS screenshot captured** on an iPhone 17 Pro Max simulator
  (1320×2868, meets the 6.9" App Store Connect requirement) — see
  `store_assets/screenshots_ios/01_home.png`. A second screen (Settings)
  wasn't captured — UI automation against the simulator wasn't reliable in
  this environment — and none were captured on a real device.

Still open (only you can do these — no App Store Connect/Apple ID login
access from here):

- [ ] **Confirm the bundle ID decision above** — resolve any mismatch with
  an existing App Store Connect app record if one already exists under the
  old ID.
- [ ] Create/confirm the app entry in App Store Connect (app name, primary
  category, age rating, App Privacy questionnaire — answers drafted below).
- [ ] Upload `build/ios/ipa/khsae_tei.ipa` via Transporter or `xcrun altool`
  / `xcrun notarytool`-equivalent (`man altool`).
- [ ] Capture the remaining App Store screenshots (Settings screen at
  minimum; ideally on a real device rather than simulator) at 6.9" and
  6.5"/5.5" sizes as required by App Store Connect.
- [ ] Fill in App Store listing text (see draft below — written for Play
  Store but reusable) and submit for review.
- [ ] **Commit the `ios/Runner.xcodeproj/project.pbxproj` changes** (bundle
  ID, manual signing, device family) — currently uncommitted in the working
  tree.

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

## App Store Connect — field-by-field

Everything to paste into App Store Connect, in the order the fields appear.
Items marked **(you decide)** are choices only you can make; everything else
is ready to copy in as-is.

**App Information**
- Name: `ខ្សែតី KHSAE TEI` (16 chars, limit 30)
- Subtitle (30 char limit): `Whip your phone to hit Enter` (28 chars) — shows under the name in search results
- Primary category: Utilities
- Secondary category (optional): Productivity
- Content Rights: "Does not contain, show, or access third-party content" → **No** third-party content

**Age Rating questionnaire** — answer **None/No** to every question (no
violence, mature/suggestive content, gambling, horror, unrestricted web
access, user-generated content, or messaging with strangers). Result: **4+**.

**Pricing and Availability**
- Price: Free **(you decide the tier — $0 matches the listing copy)**
- Availability: all countries/regions, or restrict as you prefer **(you decide)**

**App Privacy**
- For every data category (Contact Info, Health, Financial, Location, etc.)
  select **"Data Not Collected"** — matches the Data Safety answers above
- Privacy Policy URL: `https://rathanaksreang.github.io/khsae_tei/privacy-policy.html`
  (live once GitHub Pages is enabled, see Android section above)

**Version Information (1.0.0)**
- Promotional text (170 char limit, editable without re-review, 122 chars):
  > Swing your phone like a whip to send Enter to your paired desktop — no
  > cloud, no accounts, everything stays on your LAN.
- Description (4000 char limit): reuse the "Full description draft" above
- Keywords (100 char limit, comma-separated, no spaces after commas to save
  room, 89 chars):
  `whip,remote control,gesture,desktop,keyboard,productivity,accessibility,LAN,local network`
- Support URL (required): `https://github.com/RathanakSreang/khsae_tei/issues`
  — there's no dedicated website; GitHub Issues is a normal choice for an
  indie/open-source app **(swap if you'd rather use something else)**
- Marketing URL (optional): leave blank, or `https://github.com/RathanakSreang/khsae_tei`
- Copyright: `2026 Socheat Leng` (matches the Apple Developer team/account
  name) **(confirm this is the legal name you want on the listing)**

**Build** — select the build from `build/ios/ipa/khsae_tei.ipa` once uploaded
via Transporter.

**App Review Information**
- Sign-in required: No (there are no accounts)
- Contact info: your name, a phone number **(you decide)**, sreangrathanak@gmail.com
- Notes for the reviewer — flag this because the app's core action needs a
  paired desktop, which reviewers won't have:
  > KHSAE TEI is a companion remote-control app: it pairs with a desktop app
  > from the same project over the local network. Without a paired desktop,
  > reviewers can still see and navigate the full pairing flow (QR scan,
  > auto-discovery, manual entry, Settings), but the "send Enter" action only
  > completes once paired to a desktop on the same LAN. Happy to provide a
  > screen recording or arrange a live test — sreangrathanak@gmail.com.
  **(consider attaching a short demo video/recording in App Store Connect if
  reviewers reject for "unable to test core functionality" — this is common
  for LAN-pairing apps)**

**Screenshots**
- 6.9" (iPhone 16/17 Pro Max): have `01_home.png` (1320×2868) — still need a
  Settings screenshot at this size
- 6.5"/5.5": App Store Connect will state at upload time whether these are
  still required for your minimum iOS target (13+) — check there rather than
  assuming, Apple's size requirements have changed over time

## Screenshots (Android)

Re-captured 2026-08-10 on a real device (Samsung Galaxy Note20, Android 13,
1080×2400) with the debug banner suppressed, replacing the earlier
iOS-simulator captures. Both screens share the dark/cosmic theme
(`lib/theme.dart`, `lib/widgets.dart`):

- `store_assets/screenshots/01_home.png` — Home dashboard
- `store_assets/screenshots/02_settings.png` — Settings (connection setup)

1080×2400 is within Play Console's phone screenshot requirements (16:9–9:16
aspect ratio, min 320px).

## Screenshots (iOS)

- `store_assets/screenshots_ios/01_home.png` — Home dashboard, captured on
  an iPhone 17 Pro Max simulator (1320×2868, meets the 6.9" requirement).

Still needed before submission: a Settings screenshot, and ideally
re-capturing on a real device — the simulator screenshot is fine for
review but a physical-device capture (like the Android ones) is more
representative.

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

iOS:
- [x] Distribution signing (cert + provisioning profile for team
  `7PSLDSBLKA`), CocoaPods, `flutter build ipa --release` — all done, see
  above. Bundle ID is now `com.khsaetei.app`.
- [ ] Confirm the bundle ID against any existing App Store Connect app
  record (see note above).
- [ ] Capture remaining screenshots (Settings, ideally real device).
- [ ] Commit the `project.pbxproj` changes.
- [ ] Rest is App Store Connect UI work: create/confirm the app, upload
  `build/ios/ipa/khsae_tei.ipa`, fill in listing + App Privacy
  questionnaire, submit.

Both:
- [x] `version: 1.0.0+2` (bumped from `+1` in a later commit) — current and
  correct for the first release.
