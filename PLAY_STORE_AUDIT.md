# HabitGenius — Google Play Store Publishing Audit

**App Name:** HabitGenius  
**Package ID:** `com.habitgenius`  
**Version:** 1.0.0 (versionCode 1)  
**Platform:** Android (minSdk 26 / Android 8.0+)  
**Audit Date:** May 6, 2026  
**Status key:** ✅ Done · ⚠️ Needs action · ❌ Blocker

---

## 1. App Store Listing

### 1.1 Required Assets

| Asset | Spec | Status | Notes |
|---|---|---|---|
| App icon (512×512 PNG) | 32-bit PNG, no alpha | ⚠️ | `iconHG.png` used for launcher icon generation — verify final 512×512 export is clean, no transparency |
| Feature graphic | 1024×500 PNG/JPG | ❌ | Not yet created — required for Play Store page |
| Screenshots — Phone | Min 2, max 8 per device class (portrait 9:16 recommended) | ❌ | Not yet captured |
| Screenshots — 7" tablet | Optional but recommended | ❌ | Not yet captured |
| Screenshots — 10" tablet | Optional but recommended | ❌ | Not yet captured |
| Short description | Max 80 characters | ❌ | Not yet written |
| Full description | Max 4000 characters | ❌ | Not yet written |
| App category | Productivity / Health & Fitness | ❌ | Not yet selected |
| Content rating questionnaire | Play Console mandatory | ❌ | Not yet completed |
| Privacy policy URL | Must be hosted, publicly accessible | ❌ | Not yet created or hosted |

### 1.2 Suggested Store Listing Copy

**Short description (≤ 80 chars):**
> Habits · Mood · Focus · Journal · Expenses — all in one app.

**Tags to include in full description:**
habit tracker, mood journal, pomodoro timer, expense manager, daily planner, productivity, streak tracker, focus timer, personal finance, wellness

---

## 2. Privacy Policy

| Item | Status | Notes |
|---|---|---|
| Privacy policy page live at a public URL | ❌ | **Blocker** — Google Play requires this for any app |
| Data collection disclosure | ⚠️ | App uses Firebase Analytics and Firebase Auth — must disclose in policy |
| Firebase Analytics disclosed | ❌ | Auto-collects session data, device info, first_open events |
| Firebase Auth (Google Sign-In) disclosed | ❌ | Collects Google account email, display name, UID |
| Firestore entitlement data disclosed | ❌ | Stores `isPro` flag per user in Firestore |
| Google Play Billing data disclosed | ❌ | Purchase tokens handled by Google Play; disclose receipt retention |
| Local data (JSON file) disclosed | ❌ | All habit/journal/mood/expense data lives in user-controlled file |
| Data deletion policy | ❌ | Must explain how users can delete their data |
| Data safety form in Play Console | ❌ | Separate from privacy policy — must be filled in Play Console |

### 2.1 Data Safety Form (Play Console) — Required Answers

| Question | Answer |
|---|---|
| Does the app collect or share user data? | Yes |
| Data types collected | Name, Email (Firebase Auth); App activity (Firebase Analytics); In-app purchase history |
| Is data encrypted in transit? | Yes (HTTPS / TLS for all Firebase traffic) |
| Can users request data deletion? | Must implement — add "Delete account" option in Settings |

---

## 3. App Permissions Audit

All permissions declared in `AndroidManifest.xml`:

| Permission | Purpose | Justification needed? |
|---|---|---|
| `INTERNET` | Google Sign-In, Firebase, in-app purchase | Standard — no justification needed |
| `POST_NOTIFICATIONS` | Habit reminders (Android 13+) | Requested at runtime contextually ✅ |
| `SCHEDULE_EXACT_ALARM` (≤ API 32) | Exact habit reminders | Must handle `ACTION_APPLICATION_DETAILS_SETTINGS` redirect ⚠️ |
| `USE_EXACT_ALARM` (API 33+) | Exact habit reminders | Auto-granted — no user prompt needed ✅ |
| `RECEIVE_BOOT_COMPLETED` | Re-schedule reminders after reboot | Low-risk, no justification needed |
| `VIBRATE` | Notification vibration | Low-risk ✅ |
| `READ_EXTERNAL_STORAGE` (≤ API 32) | File picker for data file location | Required for SAF on older Android ✅ |
| `WRITE_EXTERNAL_STORAGE` (≤ API 29) | Write data file to chosen location | Required for API ≤ 29 ✅ |

**No sensitive permissions** (camera, microphone, contacts, location, SMS) are used. ✅

---

## 4. In-App Purchase Setup

| Item | Status | Notes |
|---|---|---|
| Product ID `habitgenius_pro_lifetime` created in Play Console | ❌ | Must create as **one-time product** (not subscription) |
| Product price set | ❌ | Decide pricing (e.g. $4.99 one-time) |
| Purchase tested on a real device via closed testing | ❌ | Test purchases must be validated before launch |
| Restore purchase flow tested | ❌ | `PurchaseService.init()` calls `restorePurchases()` — verify on reinstall |
| Firestore `isPro` write after purchase verified | ❌ | `EntitlementService.grantPro()` called from `PurchaseService._onPurchaseUpdates()` |
| License key mismatch handled gracefully | ⚠️ | Ensure `PurchaseService` handles `PurchaseStatus.error` without crashing |
| Billing client billing unavailable handled | ✅ | `_available = false` guard in `PurchaseService.init()` |

---

## 5. Build & Signing

| Item | Status | Notes |
|---|---|---|
| Release keystore created | ✅ | `habitgenius-release.keystore` (referenced in `build.gradle.kts`) |
| Keystore backed up securely | ⚠️ | **Critical** — lost keystore = cannot update the app ever again. Keep offline backup. |
| Release build type uses release signing config | ✅ | `signingConfig = signingConfigs.getByName("release")` |
| `isMinifyEnabled` in release | ⚠️ | Currently `false` — enable ProGuard/R8 for smaller APK and obfuscation |
| `isShrinkResources` in release | ⚠️ | Currently `false` — enable to reduce APK size |
| `targetSdk` | ⚠️ | Uses `flutter.targetSdkVersion` — verify this resolves to **35** (required as of Aug 2024) |
| Release AAB built successfully | ❌ | Run `flutter build appbundle --release` and verify |
| AAB uploaded to Play Console (Internal Testing) | ❌ | Upload before expanding to wider release tracks |
| App size under 150MB AAB limit | ✅ | Flutter apps are typically 15–40MB |
| `versionCode` increment strategy | ⚠️ | versionCode = 1 — must increment for every Play Store upload |
| `applicationId` finalised | ✅ | `com.habitgenius` |

### 5.1 Recommended build.gradle.kts changes before release

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = true       // enable R8
        isShrinkResources = true     // remove unused resources
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

---

## 6. Firebase & Google Services

| Item | Status | Notes |
|---|---|---|
| `google-services.json` present in `android/app/` | ✅ | |
| SHA-1 fingerprint (release keystore) added to Firebase project | ⚠️ | **Required** for Google Sign-In to work on release builds. See `firebase-sha-fingerprints.md` |
| SHA-256 fingerprint added to Firebase project | ⚠️ | Required for Google Play App Signing compatibility |
| Firebase Auth — Google Sign-In enabled in Firebase Console | ⚠️ | Verify in Firebase Console → Authentication → Sign-in providers |
| Firestore security rules reviewed | ⚠️ | Default rules may be open. Add `users/{uid}` read/write only for matching uid |
| Firestore data deletion (user account deletion) | ❌ | Must implement "Delete Account" to comply with Play policy |
| Firebase Analytics data retention configured | ⚠️ | Default 14 months; confirm acceptable for privacy policy |
| Firebase project on Blaze plan (pay-as-you-go) | ⚠️ | Spark free tier limits Firestore writes — upgrade before launch |

### 6.1 Recommended Firestore Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## 7. Google Play Policy Compliance

### 7.1 Developer Program Policies

| Policy | Status | Notes |
|---|---|---|
| App performs as described | ✅ | Core features (habits, mood, focus, journal, expenses) all implemented |
| No deceptive behaviour | ✅ | Tier limits clearly communicated via upgrade prompts |
| No malware / harmful code | ✅ | No external code execution; no web scraping |
| User data handled with care | ⚠️ | Must add account deletion feature |
| In-app purchases disclosed upfront | ⚠️ | "Upgrade to Pro" CTA visible; ensure Play Store listing also states free/paid |
| No misleading subscription phrasing | ✅ | One-time purchase only (lifetime unlock) |
| Target audience is adults (13+) | ✅ | Content rating should be "Everyone" |
| No children's app features | ✅ | No content targeting under-13 |

### 7.2 Content Rating (IARC Questionnaire)

Recommended answers:
- Violence: None
- Sexual content: None
- Profanity: None
- Controlled substances: None
- Personal/social info collection: Yes (Firebase Auth email)
- **Expected rating: Everyone (E)**

### 7.3 Families Policy

App is **not** targeted at children — no action needed under Families Policy.

### 7.4 Financial Features Policy

The app includes expense tracking (personal budgeting). This is **not** regulated fintech (no bank connections, no payment processing, no investment advice). No additional declaration is required.

---

## 8. Account Deletion Requirement

Google Play requires that apps offering account creation also provide a way to **delete the account and associated data**.

| Item | Status | Notes |
|---|---|---|
| "Delete Account" option in Settings | ❌ | **Blocker** — required since May 2023 Play policy update |
| Deletes Firebase Auth user | ❌ | `FirebaseAuth.instance.currentUser?.delete()` |
| Deletes Firestore `users/{uid}` document | ❌ | Remove `isPro` record |
| Clears local SharedPreferences | ❌ | Remove all stored keys |
| Clears local data file (optional but recommended) | ❌ | Prompt user: "Also delete local data?" |
| Confirmation dialog before deletion | ❌ | Must warn this is irreversible |

---

## 9. App Functionality Checklist

### 9.1 Core Features — Implementation Status

| Feature | Implemented | Notes |
|---|---|---|
| Splash screen | ✅ | |
| Welcome / Auth screen | ✅ | |
| Google Sign-In | ✅ | |
| Guest mode | ✅ | |
| Onboarding (3 slides) | ✅ | |
| Home screen — summary stats | ✅ | |
| Home screen — Today's habits | ✅ | |
| Home screen — This Week expansion | ✅ | Batch 6 rolling animation |
| Habits — Checkbox / Counter / Timer / Checklist | ✅ | |
| Habits — Schedule presets (Daily/Weekdays/Weekends/Weekly/Monthly/Custom) | ✅ | Batch 6 |
| Habits — Yearly heatmap | ✅ | |
| Habits — Streak tracking | ✅ | |
| Habits — Reminders (push notifications) | ✅ | Timezone fix in Batch 6 |
| Mood tracking — 5 levels + tags | ✅ | |
| Mood — Monthly calendar | ✅ | |
| Mood — Yearly heatmap | ✅ | |
| Focus timer — Pomodoro / Timer / Stopwatch | ✅ | Batch 6 mode chips |
| Focus timer — auto-save on completion | ✅ | |
| Journal — Create / edit / delete entries | ✅ | |
| Journal — Markdown preview | ✅ | |
| Journal — Tag filter | ✅ | |
| Expenses — Transactions (expense/income/transfer) | ✅ | |
| Expenses — Accounts | ✅ | |
| Expenses — Timeline line chart | ✅ | Batch 6 |
| Settings — Theme color picker | ✅ | |
| Settings — Dark/Light/System mode | ✅ | |
| Settings — Notification toggles | ✅ | |
| Settings — Data file location | ✅ | |
| Settings — Manual sync | ✅ | |
| Settings — Export/Import backup | ✅ | |
| In-app purchase (Pro upgrade) | ✅ | Needs Play Console product setup |
| Tier limits enforced (Guest/Free/Pro) | ✅ | |
| Upgrade prompt sheets | ✅ | |

### 9.2 Known Open Issues (TODOS.md Batch 6 — Partially Done)

The following items from TODOS.md Batch 6 were tracked as open at the time of this audit. Review individually before submitting to Play Store review:

| TODO # | Description | Risk |
|---|---|---|
| **33** | Expense chip visibility in light mode | Low — cosmetic |
| **33.1** | Habit screen chip visibility in light mode | Low — cosmetic |
| **33.2** | More schedule presets | Low — enhancement |
| **34** | Non-scheduled habits dimmed in All view | Low — cosmetic |
| **35** | Counter decrement edge cases | Medium — UX |
| **36** | Notifications timezone bug | High — core feature broken |
| **37** | Timer habit undo confirmation | Medium — UX |
| **38/38.1** | Heatmap borders | Low — cosmetic |
| **39** | Expense line chart | Low — cosmetic |
| **40** | Journal double border | Low — cosmetic |
| **41/41.1** | This Week animation + name wrap | Low — cosmetic |
| **42/42.1** | Focus mode chips + block shape | Medium — UX |

> All Batch 6 items have since been implemented and fixed (as of the latest commits). Verify each on device before release.

---

## 10. Performance & Stability

| Item | Status | Notes |
|---|---|---|
| App cold start time | ⚠️ | Target < 1.5s; profile on low-end device (e.g. Pixel 3a) |
| Memory usage during normal use | ⚠️ | Check with Flutter DevTools — watch for leaks in Riverpod providers |
| Data file read/write under 300ms | ⚠️ | Large data files (1000+ logs) — profile `DataService._save()` |
| App does not crash on empty state | ✅ | Empty-state widgets in place |
| App does not crash on first launch (no data file) | ✅ | `DataService.load()` handles missing file |
| App recovers from corrupt data file | ⚠️ | `DataService.load()` has try/catch but recovery path needs manual test |
| No `print()` statements in release | ⚠️ | Scan for `print(` — use `debugPrint` only |
| `flutter analyze` clean | ✅ | Zero issues on last run |
| No deprecated API usage | ⚠️ | Run `flutter analyze` after upgrading to latest Flutter stable |

---

## 11. UI / UX Quality Gates

| Item | Status | Notes |
|---|---|---|
| Light mode contrast (WCAG AA) | ⚠️ | Chip contrast fixed in Batch 6; do a full sweep |
| Dark mode contrast | ✅ | Primary design target |
| Font scaling (large text / accessibility) | ⚠️ | Test at 200% font scale on device |
| Landscape orientation | ⚠️ | Locked to portrait? If not, test all screens in landscape |
| Physical back button (Android) | ⚠️ | Test back navigation on all modal sheets and dialogs |
| Keyboard avoidance | ✅ | `windowSoftInputMode="adjustResize"` set |
| Loading states present | ✅ | Saving spinners and skeleton states implemented |
| Error states shown to user | ✅ | `AppToast` error messages in place |
| No hardcoded strings (internationalisation) | ⚠️ | Not localised for v1; acceptable if targeting English-speaking markets only |

---

## 12. Security

| Item | Status | Notes |
|---|---|---|
| No API keys in source code | ✅ | Firebase config is in `google-services.json` (not committed to public repo) |
| `google-services.json` in `.gitignore` | ⚠️ | Verify it is gitignored if repo is public |
| No hardcoded passwords or secrets | ✅ | Keystore passwords read from environment variables (`CM_KEYSTORE_PASSWORD`) |
| `android:allowBackup="false"` | ✅ | Set in `AndroidManifest.xml` — prevents ADB backup of sensitive data |
| `android:networkSecurityConfig` present | ✅ | Custom config referenced in manifest |
| HTTPS enforced | ✅ | All Firebase SDK traffic uses TLS |
| Local data file not accessible to other apps | ✅ | Stored in app documents directory (internal) for Guest; user-chosen path for Registered (SAF) |
| ProGuard / R8 enabled for release | ❌ | Currently disabled — enable before upload (see §5.1) |

---

## 13. Testing Checklist

### 13.1 Manual Test Scenarios (run before each release)

**Auth flow:**
- [ ] Guest mode — all tier limits enforced (1 habit, 5 journal entries, no mood/expenses)
- [ ] Google Sign-In — works on first launch
- [ ] Sign-out and sign back in — data reloads correctly
- [ ] Guest → Google Sign-In transition — shows migration notice

**Habits:**
- [ ] Create habit with each progress type (Checkbox / Counter / Timer / Checklist)
- [ ] Create habit with each schedule preset (Daily / Weekdays / Weekends / Weekly / Monthly / Custom)
- [ ] Set habit reminder — notification fires at correct local time
- [ ] Mark counter habit done (Today section tap = increment; long-press = decrement)
- [ ] Mark timer habit — minute picker opens; save updates progress ring
- [ ] Undo completed timer habit — shows confirmation dialog; clears correctly
- [ ] Archive and restore habit
- [ ] Delete habit — removed from all views
- [ ] Yearly heatmap overlay — press and hold on Today circle

**Mood:**
- [ ] Log mood for today — persists after app restart
- [ ] Update mood — only one entry per day
- [ ] Monthly calendar shows correct emoji per day
- [ ] Yearly heatmap — emoji in each cell, navigation between years

**Focus:**
- [ ] Pomodoro mode — 25 min timer, break prompt at end
- [ ] Timer (countdown) mode — custom duration works
- [ ] Stopwatch mode — counts up, manual stop
- [ ] Session saves correctly after completion
- [ ] Timer persists through screen lock

**Journal:**
- [ ] Create, edit, delete entry
- [ ] Markdown preview toggle works
- [ ] Tag filter works
- [ ] Guest 5-entry limit enforced

**Expenses:**
- [ ] Add expense/income/transfer
- [ ] Account balance updates correctly
- [ ] Timeline chart renders with 1 and many data points
- [ ] Registered 4-per-day limit enforced

**In-App Purchase:**
- [ ] "Upgrade to Pro" sheet opens from all locked gates
- [ ] Purchase flow completes on test device
- [ ] Pro features unlock immediately after purchase
- [ ] Restore purchase works after reinstall

**Settings:**
- [ ] Theme color change persists after restart
- [ ] Dark / Light / System mode toggle works
- [ ] Data file path change — app reads/writes to new location
- [ ] Manual sync push/pull
- [ ] Export backup creates valid JSON file
- [ ] Import backup restores data

**Notifications:**
- [ ] Habit reminder fires at correct local time (not UTC)
- [ ] Notification re-schedules after device reboot
- [ ] Cancelling reminder in edit habit cancels notification

### 13.2 Device Matrix (recommended)

| Device | Android version | Reason |
|---|---|---|
| Pixel 8 / emulator | Android 14 (API 34) | Latest API — primary target |
| Pixel 6a | Android 13 (API 33) | Most common in field |
| Samsung Galaxy A-series | Android 12 (API 32) | Samsung OneUI skin |
| Old low-end (e.g. Pixel 3a) | Android 9/10 (API 28–29) | Min spec validation |

---

## 14. Play Console Setup Checklist

| Step | Status | Notes |
|---|---|---|
| Developer account verified | ⚠️ | Requires $25 one-time fee + identity verification |
| App created in Play Console | ❌ | Create new app → "HabitGenius" |
| App category set | ❌ | Productivity |
| Content rating completed | ❌ | IARC questionnaire |
| Target countries selected | ❌ | Start with English-speaking markets |
| Pricing & distribution configured | ❌ | Free app with in-app purchase |
| Privacy policy URL added | ❌ | Required field |
| Data safety form completed | ❌ | Required field |
| Internal test track — testers added | ❌ | Add at least 1 tester email |
| AAB uploaded to internal track | ❌ | First upload step |
| Store listing text + screenshots uploaded | ❌ | |
| App reviewed internally before promoting to production | ❌ | |
| Production release — rollout at 10% | ❌ | Gradual rollout recommended for first release |

---

## 15. Pre-Submit Blockers Summary

The following items **must** be completed before submitting for Play Store review:

| # | Blocker | File / Location |
|---|---|---|
| 1 | **Privacy policy URL** — must be publicly hosted | External (e.g. GitHub Pages, simple webpage) |
| 2 | **Data safety form** — must be filled in Play Console | Play Console → Policy → Data safety |
| 3 | **"Delete Account" feature** — Play policy requirement since May 2023 | `lib/features/settings/settings_screen.dart` |
| 4 | **Feature graphic (1024×500)** | Required for store listing |
| 5 | **Screenshots** (min 2 phone screenshots) | Required for store listing |
| 6 | **Release AAB built and signed** | `flutter build appbundle --release` |
| 7 | **In-app product created** in Play Console | `habitgenius_pro_lifetime` one-time product |
| 8 | **SHA-1 + SHA-256 added to Firebase** for release keystore | Firebase Console → Project settings → Android app |
| 9 | **R8/ProGuard enabled** in release build | `android/app/build.gradle.kts` |
| 10 | **Keystore backed up offline** | Irreversible if lost |

---

## 16. Post-Launch Recommendations

- Set up **crash reporting** via Firebase Crashlytics (`firebase_crashlytics` package)
- Configure **Play Store ratings prompt** using the `in_app_review` package — trigger after 3rd successful habit completion
- Set up **Codemagic release workflow** to auto-publish to Internal Track on push to `main`
- Monitor **Firebase Analytics dashboard** for funnel drop-off (Guest → Register → Pro)
- Plan `1.0.1` patch release within 2 weeks of launch to address any store review feedback
- Add **iOS build target** when ready for App Store expansion (Sprint 10+)
