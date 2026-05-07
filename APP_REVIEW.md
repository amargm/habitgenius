# HabitGenius — Complete App Review
**Date:** May 8, 2026 | **Commit:** 8240a2f | **Reviewed by:** GitHub Copilot

---

## Overview

This document is a full audit of the HabitGenius Flutter + Kotlin codebase — functionalities, bugs, app crash vectors, widget data correctness, Drive sync, edge cases, and fail-safes for every feature. Each finding includes the root cause, affected file(s), and the exact fix required.

**Severity scale:**
- 🔴 **Critical** — data loss, silent crash, or completely broken feature
- 🟠 **High** — significant bug affecting UX or data correctness
- 🟡 **Medium** — edge-case bug or non-fatal incorrect behaviour
- 🟢 **Low** — UX polish, dead code, or minor inconsistency

---

## Table of Contents

1. [Habit Scheduling Bugs](#1-habit-scheduling-bugs)
2. [Drive Sync Issues](#2-drive-sync-issues)
3. [Widget Data Issues](#3-widget-data-issues)
4. [Focus Timer Bugs](#4-focus-timer-bugs)
5. [Home Screen & Auth Bugs](#5-home-screen--auth-bugs)
6. [Notification Service Bugs](#6-notification-service-bugs)
7. [Data Service & Storage](#7-data-service--storage)
8. [Expense & Mood Features](#8-expense--mood-features)
9. [App Lifecycle & Performance](#9-app-lifecycle--performance)
10. [Edge Cases & Fail-Safes](#10-edge-cases--fail-safes)
11. [Summary Table](#11-summary-table)
12. [Priority Fix Order](#12-priority-fix-order)

---

## 1. Habit Scheduling Bugs

---

### 🔴 BUG-001 — Sunday habits never appear as scheduled in ANY Android widget

**Affected files:**
- `android/app/src/main/kotlin/com/habitgenius/habitgenius/HabitsWidgetActionReceiver.kt`

**Root cause:**

The Flutter data model stores `scheduleDays` with the convention `0 = Sunday, 1 = Monday … 6 = Saturday` (documented in `habit.dart` and confirmed in `add_habit_screen.dart`'s `_DayPicker` which iterates `i = 0..6`). The Kotlin widget converts Java Calendar DOW to an ISO-like value where `1 = Monday … 7 = Sunday`. The comparison then does:

```kotlin
val isoDow = if (javaDow == Calendar.SUNDAY) 7 else javaDow - 1
(0 until scheduleDaysArr.length()).any { scheduleDaysArr.getInt(it) == isoDow }
```

For Sunday, Flutter stores `0` and Kotlin produces `7`. The comparison `0 == 7` is always false — Sunday habits are invisible to the widget every Sunday.

**Fix:**
```kotlin
// Map isoDow Sunday (7) → Flutter's Sunday (0) before comparing
val widgetDow = if (isoDow == 7) 0 else isoDow
(0 until scheduleDaysArr.length()).any { scheduleDaysArr.getInt(it) == widgetDow }
```

Apply this same fix in **both** the `"weekly"` case and any new cases added for BUG-002/003.

---

### 🔴 BUG-002 — `specific` and `custom` habits (Weekdays, Weekends, Custom) always appear scheduled in widgets

**Affected files:**
- `android/app/src/main/kotlin/com/habitgenius/habitgenius/HabitsWidgetActionReceiver.kt`

**Root cause:**

The Kotlin `isScheduledOn()` helper handles `"daily"`, `"weekly"`, and `"interval"`. Everything else falls through to `else -> true`:

```kotlin
return when (schedule) {
    "daily"    -> true
    "weekly"   -> { /* day check */ }
    "interval" -> { /* interval check */ }
    else       -> true   // ← catches "specific", "custom", "monthly"
}
```

Flutter's `_SchedulePreset.weekdays` (Mon–Fri), `weekends` (Sat–Sun), and `custom` all map to `HabitSchedule.specific`, serialised as `"specific"`. `HabitSchedule.custom` serialises as `"custom"`. Both fall into `else -> true`, so these habits show as scheduled every day in the widget — a "Weekdays only" habit appears on Saturday and Sunday.

**Fix:** Add explicit cases using the `widgetDow` remapping from BUG-001:
```kotlin
"specific", "custom" -> {
    if (scheduleDaysArr == null || scheduleDaysArr.length() == 0) true
    else {
        val widgetDow = if (isoDow == 7) 0 else isoDow
        (0 until scheduleDaysArr.length()).any { scheduleDaysArr.getInt(it) == widgetDow }
    }
}
```

---

### 🔴 BUG-003 — Monthly habits always appear scheduled every day in widgets

**Affected files:**
- `android/app/src/main/kotlin/com/habitgenius/habitgenius/HabitsWidgetActionReceiver.kt`

**Root cause:** Same `else -> true` fall-through as BUG-002. The `"monthly"` schedule type is not handled.

**Fix:** Add a `"monthly"` case that checks the day-of-month:
```kotlin
"monthly" -> {
    val dayOfMonth = cal.get(Calendar.DAY_OF_MONTH)
    if (scheduleDaysArr == null || scheduleDaysArr.length() == 0) true
    else (0 until scheduleDaysArr.length()).any { scheduleDaysArr.getInt(it) == dayOfMonth }
}
```

---

### 🟠 BUG-004 — In-app weekly habit view uses Sun–Sat week; widget uses Mon–Sun week

**Affected files:**
- `lib/core/utils/habit_helpers.dart` — `weeklyCompletion()`

**Root cause:**
```dart
static List<bool> weeklyCompletion(Habit habit, List<HabitLog> logs, DateTime date) {
  final weekday = date.weekday % 7; // 0 = Sunday
  final sunday = date.subtract(Duration(days: weekday));
  return List.generate(7, (i) { /* Sun, Mon, Tue, Wed, Thu, Fri, Sat */ });
}
```

`WidgetSyncService._buildHabitsJson` uses Monday as the week start, matching ISO 8601. The in-app weekly habit view (the "Week" filter chip in `habits_screen.dart`) calls `weeklyCompletion`, which starts on Sunday. This means the day columns shown in the widget and the day columns shown in the Week view are offset, leading to confusing inconsistency.

**Fix:** Change `weeklyCompletion` to start on Monday:
```dart
static List<bool> weeklyCompletion(Habit habit, List<HabitLog> logs, DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return List.generate(7, (i) {
    final day = monday.add(Duration(days: i)); // Mon, Tue … Sun
    if (!isScheduledOn(habit, day)) return false;
    return isCompletedOn(habit, logs, _fmtDate(day));
  });
}
```

---

## 2. Drive Sync Issues

---

### 🟠 BUG-005 — `isAuthRevoked` detection misses `HttpException`, HTTP 401, and `insufficient_scope` errors

**Affected files:**
- `lib/core/providers/cloud_sync_provider.dart`

**Root cause:**
```dart
final isAuth =
    e is DriveServiceException &&
    (e.message.contains('authenticated') ||
        e.message.contains('Not auth'));
```

The Google Drive API can throw `DetailedApiRequestError` with HTTP 401, or an `HttpException` containing `insufficient_scope` or `invalid_grant`. These are **not** `DriveServiceException` instances. When they occur, `isAuthRevoked = false`, so the UI shows the generic "Sync failed — please try again" with no clear recovery path, instead of the "Reconnect" button.

**Fix:** Broaden the detection with a helper:
```dart
bool _isAuthError(Object e) {
  final s = e.toString().toLowerCase();
  if (e is DriveServiceException) {
    return s.contains('authenticated') || s.contains('not auth') ||
           s.contains('scope') || s.contains('401') || s.contains('invalid_grant');
  }
  return s.contains('401') || s.contains('invalid_grant') || s.contains('insufficient_scope');
}
```

Use `_isAuthError(e)` in `_doSync` and update `_friendlyError` to handle `HttpException`:
```dart
String _friendlyError(Object e) {
  if (e is TimeoutException) return 'Sync timed out — will retry next time';
  if (e is SocketException) return 'No internet connection';
  if (_isAuthError(e)) return 'Drive access revoked — tap Reconnect to restore';
  if (e is DriveServiceException) return e.message;
  return 'Sync failed — please try again';
}
```

---

### 🟠 BUG-006 — Race condition: `disableSync()` state overridden by in-flight `_doSync`

**Affected files:**
- `lib/core/providers/cloud_sync_provider.dart`

**Root cause:** `_doSync` has an early-exit guard (`if (state.status == SyncStatus.syncing) return`) but this doesn't stop a sync that has **already started**. If `disableSync()` sets state to `disabled`, an already-running `_doSync` completes and then sets `state = state.copyWith(status: SyncStatus.synced)`, overriding the `disabled` status. The sync toggle visually re-enables itself.

**Fix:** Add a cancellation flag:
```dart
bool _syncCancelled = false;

Future<void> disableSync() async {
  _syncCancelled = true;
  _debounceTimer?.cancel();
  _debounceTimer = null;
  await _prefs.setBool(_kSyncEnabled, false);
  state = CloudSyncState(status: SyncStatus.disabled, lastSynced: state.lastSynced);
}

Future<void> _doSync({...}) async {
  _syncCancelled = false;
  ...
  // After await _runSync(...):
  if (_syncCancelled) return; // user disabled sync mid-flight — discard result
  final now = DateTime.now().toUtc();
  await _prefs.setInt(_kLastSynced, now.millisecondsSinceEpoch);
  state = state.copyWith(status: SyncStatus.synced, lastSynced: now);
}
```

---

### 🟠 BUG-007 — Drive sync `scheduleUpload` passes `googleSignIn` which can be non-null even after sign-out

**Affected files:**
- `lib/app.dart`, `lib/core/providers/cloud_sync_provider.dart`

**Root cause:**

In `app.dart`:
```dart
void _scheduleCloudUpload() {
  final authState = ref.read(authNotifierProvider);
  if (authState.isGuest) return;
  ref.read(cloudSyncProvider.notifier).scheduleUpload(
    dataNotifier: ...,
    googleSignIn: ref.read(authServiceProvider).googleSignIn, // always non-null
  );
}
```

`authServiceProvider.googleSignIn` returns the `GoogleSignIn` instance, which is always allocated (it's a field in `AuthService`). Even after sign-out, the instance exists but has no current user. The debounce timer fires, `_doSync` runs, `DriveService.init` calls `signInSilently()` on a signed-out instance → returns null → throws `DriveServiceException('Not authenticated')`. This surfaces as a sync error after sign-out.

**Fix:** The `if (authState.isGuest)` guard catches most cases, but add a check in `scheduleUpload` to verify `isEnabled` before scheduling (already done). Also verify the notifier's `disableSync()` is called on sign-out (see BUG-033).

---

## 3. Widget Data Issues

---

### 🟠 BUG-008 — Focus stats "today" calculation is timezone-unsafe

**Affected files:**
- `lib/core/services/widget_sync_service.dart` — `_buildFocusStatsJson()`

**Root cause:**
```dart
final todayStr = HabitHelpers.todayStr(); // "2026-05-08" (LOCAL date)
final todaySeconds = data.focusSessions
    .where((s) => s.startedAt.startsWith(todayStr)) // BUG: startedAt is UTC
    .fold<int>(0, (sum, s) => sum + s.actualDuration);
```

`s.startedAt` is stored as a UTC ISO-8601 string (e.g., `"2026-05-08T01:30:00.000Z"`). For a user in UTC+5:30, a session at 12:30 AM local is stored as `"2026-05-07T19:00:00.000Z"` — the UTC prefix is yesterday. `startsWith("2026-05-08")` returns false; the session is missed. For UTC- users the reverse happens (yesterday's session counted today).

The Focus screen itself correctly uses `.toLocal()` comparison, making the widget inconsistent with the app.

**Fix:**
```dart
final today = DateTime.now();
final todaySeconds = data.focusSessions.where((s) {
  final d = DateTime.tryParse(s.startedAt)?.toLocal();
  return d != null &&
      d.year == today.year &&
      d.month == today.month &&
      d.day == today.day;
}).fold<int>(0, (sum, s) => sum + s.actualDuration);
```

---

### 🟠 BUG-009 — Widget data not pushed on initial cold app start

**Affected files:**
- `lib/app.dart`

**Root cause:** `WidgetSyncService.pushAll()` is triggered in two places:
1. `DataNotifier._save()` — after any user mutation
2. `_pushWidgetData()` on `AppLifecycleState.resumed`

It is **never called after the initial data load** on a cold start. On first launch or after an OS process kill, the widgets show empty/stale data until the user either makes a data change or backgrounds and reopens the app.

**Fix:** In `app.dart`'s `_dataSub` listener, push widget data when data first becomes available:
```dart
_dataSub = ref.listenManual(dataNotifierProvider, (prev, next) {
  if (next.hasValue && (prev == null || !prev.hasValue)) {
    _rescheduleHabitReminders();
    _pushWidgetData(); // ← ADD: push on initial load
  }
  if (prev?.hasValue == true && next.hasValue) {
    _scheduleCloudUpload();
  }
});
```

---

### 🟡 BUG-010 — Expense widget shows "Today: -$0.00" when no expenses logged

**Affected files:**
- `android/app/src/main/kotlin/com/habitgenius/habitgenius/ExpenseWidgetProvider.kt`

**Root cause:**
```kotlin
views.setTextViewText(R.id.expense_today, "Today: -$symbol${formatAmount(todayExpense)}")
```
When `todayExpense = 0.0`, this displays "Today: -$0.00", implying a negative zero expense which looks like a display bug.

**Fix:**
```kotlin
val todayText = if (todayExpense > 0.001)
    "Today: -$symbol${formatAmount(todayExpense)}"
else
    "Today: No expenses"
views.setTextViewText(R.id.expense_today, todayText)
```

---

### 🟡 BUG-011 — Expense widget shows only the first account balance

**Affected files:**
- `android/app/src/main/kotlin/com/habitgenius/habitgenius/ExpenseWidgetProvider.kt`

**Root cause:**
```kotlin
val acc = accounts.getJSONObject(0) // always first account only
val bal = acc.optDouble("balance", 0.0)
val name = acc.optString("name", "Account")
```
Users with multiple accounts see only the first. There is no indication that other accounts exist.

**Fix (total balance):**
```kotlin
var totalBalance = 0.0
for (i in 0 until accounts.length()) {
    totalBalance += accounts.getJSONObject(i).optDouble("balance", 0.0)
}
val balanceText = "Net: $symbol${formatAmount(totalBalance)}"
views.setTextViewText(R.id.expense_balance, balanceText)
```

---

### 🟡 BUG-012 — Mood emoji in Canvas may render as boxes on API 26 (minSdk) devices

**Affected files:**
- `android/app/src/main/kotlin/com/habitgenius/habitgenius/MoodWidgetProvider.kt`

**Root cause:**
```kotlin
canvas.drawText(emoji, cx, textY, textPaint)
```
`Canvas.drawText()` relies on the system emoji font. Android 8.0 (API 26, our `minSdk`) may not have Unicode 10+ emoji in its system font. The emoji renders as a blank box on older devices.

**Short-term fix:** Increase bitmap size to at least 56dp so fallback rendering fills the space better. Set `textPaint.typeface = Typeface.DEFAULT` explicitly.

**Long-term fix:** Replace emoji with vector drawables (one `ImageView` per level), which render correctly on all API levels without font dependency.

---

### 🟡 BUG-013 — Widget data not cleared when user signs out

**Affected files:**
- `lib/core/providers/data_provider.dart` — `DataNotifier.reset()`

**Root cause:** `DataNotifier.reset()` clears the in-memory state and file path. But the widget SharedPreferences keys (`flutter.hw_widget_habits`, `flutter.hw_mood`, `flutter.hw_focus`, `flutter.hw_expenses`) still contain the previous user's data. If a second user logs in on the same device, the widgets briefly show user-1's habits/mood/finances until the first `pushAll` fires.

**Fix:**
```dart
void reset() {
  _filePath = null;
  _isGuest = null;
  state = const AsyncValue.loading();
  SyncService.instance.reset();
  WidgetSyncService.instance.pushAll(AppData.empty()).ignore(); // ← ADD
}
```

---

## 4. Focus Timer Bugs

---

### 🟡 BUG-014 — Widget-started focus sessions always categorised as "Deep Work / Pomodoro"

**Affected files:**
- `android/app/src/main/kotlin/com/habitgenius/habitgenius/FocusTimerReceiver.kt`

**Root cause:**
```kotlin
put("mode", "Pomodoro")
put("category", "Deep Work")
```
Sessions started from the home-screen widget always appear in the Focus screen history as "Deep Work / Pomodoro", regardless of the user's last-selected category and mode in the app.

**Fix:** Add a `hw_last_focus_config` SharedPreferences key written by Flutter when `pushAll` is called, and read it in `handleStart()`:
```kotlin
val lastCategory = prefs.getString("flutter.hw_last_category", "Deep Work") ?: "Deep Work"
val lastMode = prefs.getString("flutter.hw_last_mode", "Pomodoro") ?: "Pomodoro"
put("category", lastCategory)
put("mode", lastMode)
```
In `WidgetSyncService._buildFocusStatsJson`, add:
```dart
// Last used category/mode for widget-started sessions
'lastCategory': data.focusSessions.isNotEmpty
    ? data.focusSessions.last.category : 'Deep Work',
'lastMode': data.focusSessions.isNotEmpty
    ? data.focusSessions.last.mode.name : 'pomodoro',
```

---

### 🟡 BUG-015 — Focus screen doesn't warn user before navigating away mid-session

**Affected files:**
- `lib/features/focus/focus_screen.dart`

**Root cause:** A user can tap a bottom-nav tab mid-session and navigate away. The timer continues running (the `ChangeNotifierProvider` persists with `keepAlive = false` by default if not explicitly set — verify `focusSvcProvider` stays alive). The session continues in background, which is the intended behaviour. But no toast or visual indicator on the home screen tells the user a timer is running.

**Note:** `ChangeNotifierProvider` (not `keepAlive: true`) is used. The provider is scoped to the widget tree — if the Focus screen is removed from the tree, the provider is disposed and the timer stops silently.

**Fix:** Change to `keepAlive: true` (already done via `ChangeNotifierProvider` in the global app scope) or add a running-timer badge on the Focus tab in `main_shell.dart`.

---

## 5. Home Screen & Auth Bugs

---

### 🟠 BUG-016 — Guest users see mood counted in "N done / total" on home screen

**Affected files:**
- `lib/features/home/home_screen.dart`

**Root cause:**
```dart
final totalTodayActivities = todayHabits.length + 1; // +1 for mood — always
```
`AppLimits.canAccessMood` returns false for guests (they cannot log mood). Yet mood is always counted as +1 in `totalTodayActivities`. A guest with 2 habits sees "2 / 3 done" and can never reach 100%, making the progress indicator feel broken.

**Fix:**
```dart
final canLogMood = AppLimits.canAccessMood(auth.tier);
final totalTodayActivities = todayHabits.length + (canLogMood ? 1 : 0);
final doneToday = habitsDoneToday + (canLogMood && todayMood != null ? 1 : 0);
```

---

### 🟠 BUG-017 — Onboarding folder-picker UI is dead code — `resolveFilePath` ignores `customDirPath`

**Affected files:**
- `lib/core/services/data_service.dart`
- `lib/features/auth/file_setup_screen.dart`
- `lib/features/onboarding/onboarding_screen.dart`
- `lib/features/auth/welcome_screen.dart`

**Root cause:**
```dart
Future<String> resolveFilePath({bool isGuest = true, String? customDirPath}) async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/$_kFileName';
  // customDirPath is NEVER used — comment: "kept for API compatibility"
}
```
The onboarding shows `file_setup_screen.dart` (a folder picker), saves the chosen path to `PrefKeys.dataFilePath`, and passes it to `notifier.load()`. But `resolveFilePath` unconditionally uses the internal documents directory. The user goes through a folder selection UI that has absolutely zero effect on where data is stored.

**Fix:** Remove the folder-picker step from onboarding. Replace with a one-screen informational card: "Your data is stored securely on this device." Save `PrefKeys.hasSeenOnboarding = true` and remove all reads/writes of `PrefKeys.dataFilePath`. Update `SplashScreen._init()` and `welcome_screen.dart` to not reference `dataFilePath`.

---

### 🟡 BUG-018 — `signInWithGoogle` ignores locally-cached Pro status — can downgrade user

**Affected files:**
- `lib/core/providers/auth_provider.dart`

**Root cause:**
```dart
final serverIsPro = await EntitlementService.instance.checkPro();
if (serverIsPro) {
  await PurchaseService.instance.syncProFromServer(isPro: true);
}
state = AuthState(user: user, isPro: serverIsPro); // server always wins
```
If a user purchases Pro via IAP and then signs out and back in before Firestore propagates the purchase, `checkPro()` returns false → the user is downgraded for the session. The `restore()` path handles this correctly (server wins only when different from local), but `signInWithGoogle` does not consult local state.

**Fix:** Don't downgrade if local says Pro:
```dart
final localIsPro = PurchaseService.instance.isPro;
final serverIsPro = await EntitlementService.instance.checkPro();
final isPro = serverIsPro || localIsPro; // never downgrade based on server alone
if (serverIsPro && !localIsPro) {
  await PurchaseService.instance.syncProFromServer(isPro: true);
}
state = AuthState(user: user, isPro: isPro);
```

---

### 🟠 BUG-019 — `deleteAccount` doesn't handle `requires-recent-login` in the settings UI

**Affected files:**
- `lib/features/settings/settings_screen.dart`

**Root cause:** Firebase requires a recent credential for account deletion. If the user's auth token is older than ~5 minutes, `user.delete()` throws `FirebaseAuthException(code: 'requires-recent-login')`. `AuthNotifier.deleteAccount()` re-throws this. Without a specific catch in the settings UI, the user sees a generic error and their account is not deleted — with no path to retry.

**Fix:** In the account deletion button handler in `settings_screen.dart`:
```dart
} on FirebaseAuthException catch (e) {
  if (e.code == 'requires-recent-login') {
    AppToast.show(
      context,
      'Please sign in again to confirm account deletion.',
      type: ToastType.error,
    );
    // Optionally: trigger signInWithGoogle() then retry deleteAccount()
  } else {
    AppToast.show(context, e.message ?? 'Delete failed', type: ToastType.error);
  }
}
```

---

## 6. Notification Service Bugs

---

### 🟡 BUG-020 — Monthly notifications for day 29, 30, 31 skip months with fewer days

**Affected files:**
- `lib/core/services/notification_service.dart`
- `lib/features/habits/add_habit_screen.dart` — `_MonthDayPicker`

**Root cause:** `DateTimeComponents.dayOfMonthAndTime` skips months that don't have the target day. A habit set to day 31 will never fire in February, April, June, September, or November. Day 30 skips February. The user has no warning about this.

**Fix (user-facing warning):** Add a warning below the `_MonthDayPicker` in `add_habit_screen.dart`:
```dart
if (_scheduleDays.isNotEmpty && _scheduleDays.first >= 29)
  Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      'Note: This reminder will not fire in months shorter than ${_scheduleDays.first} days.',
      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
    ),
  ),
```

---

### 🟡 BUG-021 — Notification ID hash collision between habits

**Affected files:**
- `lib/core/services/notification_service.dart`

**Root cause:**
```dart
final id = habitId.hashCode.abs() % 100000; // max 100,000 IDs
```
Two different UUID habit IDs can produce the same `hashCode % 100000`. If they collide on the daily notification ID, scheduling the second habit's reminder silently cancels the first's. With only 100,000 slots, the birthday problem means a ~50% collision probability at ~316 habits — unlikely in practice but non-zero.

**Fix:** Increase the modulus:
```dart
final id = habitId.hashCode.abs() % 1_000_000;
```
Or maintain a sequential notification ID registry in SharedPreferences.

---

### 🟡 BUG-022 — Sunday weekday index `0` may not match `zonedSchedule` internals

**Affected files:**
- `lib/core/services/notification_service.dart`

**Root cause:** The comment says `scheduleDays: 0=Sun`. `_nextInstanceOfTime(timeOfDay, weekday)` receives `weekday = 0` for Sunday. Dart's `DateTime.weekday` uses `1=Mon … 7=Sun`. If `_nextInstanceOfTime` compares `candidate.weekday == weekday` directly, then `weekday=0` will never match any Dart weekday (1–7), meaning Sunday notifications are never scheduled.

**Action:** Read `_nextInstanceOfTime` and add this remap:
```dart
static TZDateTime _nextInstanceOfTime(TimeOfDay time, int? weekday) {
  // ...existing code...
  if (weekday != null) {
    // Flutter/Dart: 1=Mon…7=Sun. scheduleDays uses 0=Sun convention.
    final dartWeekday = weekday == 0 ? DateTime.sunday : weekday; // ← add
    while (scheduledDate.weekday != dartWeekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
  }
}
```

---

## 7. Data Service & Storage

---

### 🟡 BUG-023 — `DataService.saveData` `rename()` may throw on cross-filesystem paths

**Affected files:**
- `lib/core/services/data_service.dart`

**Root cause:**
```dart
final tmp = File('$filePath.tmp');
await tmp.writeAsString(json, flush: true);
await tmp.rename(filePath); // atomic only if same partition
```
`File.rename()` throws `FileSystemException` if source and destination are on different filesystem partitions. On some OEM Android devices with external SD card storage, this path is cross-filesystem. The exception propagates to `DataNotifier._save()`'s catch block and triggers a rollback — but the .tmp file is left behind.

**Fix:**
```dart
try {
  await tmp.rename(filePath);
} on FileSystemException {
  // Cross-device rename failed — copy and delete instead.
  await tmp.copy(filePath);
  await tmp.delete();
}
```

---

## 8. Expense & Mood Features

---

### 🟡 BUG-024 — "Add an account first" toast doesn't switch to the Accounts tab

**Affected files:**
- `lib/features/expenses/expenses_screen.dart`

**Root cause:**
```dart
if (accounts.isEmpty) {
  AppToast.show(context, 'Add an account first.');
  return;
}
```
The toast tells the user to add an account but doesn't switch the tab. The user must manually find and tap the Accounts tab, adding unnecessary friction especially on first use.

**Fix:**
```dart
if (accounts.isEmpty) {
  _tabs.animateTo(1); // jump to Accounts tab
  AppToast.show(context, 'Add an account first, then log transactions.');
  return;
}
```

---

### 🟡 BUG-025 — No "transactions remaining today" indicator for registered users

**Affected files:**
- `lib/features/expenses/expenses_screen.dart`

**Root cause:** Registered users have a 4 transactions/day limit (reset at midnight). There is no in-app indicator showing how many remain. Users discover the limit only when they hit the upgrade prompt, which is jarring.

**Fix:** Add a subtitle below the Transactions tab header when the user is approaching the limit:
```dart
final txToday = transactions.where((t) => t.date == _todayStr()).length;
final maxTx = AppLimits.maxTransactionsPerDay(tier);
if (tier != UserTier.pro && maxTx != AppLimits.proMaxTransactionsPerDay) {
  final remaining = maxTx - txToday;
  if (remaining <= 2) {
    Text('$remaining transaction${remaining == 1 ? "" : "s"} remaining today',
         style: TextStyle(color: remaining == 0 ? AppColors.danger : AppColors.textMuted, fontSize: 12))
  }
}
```

---

### 🟡 BUG-026 — Mood tag pre-selection not verified for edit flow

**Affected files:**
- `lib/features/mood/mood_screen.dart` — `_TodayTab`

**Root cause:** When `todayMood != null` (user already logged mood today), the Today tab should pre-select both the mood level and tags. Verify that `_TodayTab` initialises `_selectedLevel` and `_selectedTags` from `todayMood` in `initState()`.

**Action — audit this in `_TodayTab.initState()`:**
```dart
@override
void initState() {
  super.initState();
  if (widget.todayMood != null) {
    _selectedLevel = widget.todayMood!.level;
    _selectedTags = Set.from(widget.todayMood!.tags); // must exist
    _noteController.text = widget.todayMood!.note ?? '';
  }
}
```
If any of these assignments are missing, add them.

---

## 9. App Lifecycle & Performance

---

### 🟠 BUG-027 — `_rescheduleHabitReminders` fires on every app resume (expensive)

**Affected files:**
- `lib/app.dart`

**Root cause:**
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    SyncService.instance.checkAndReload(notifier);
    _rescheduleHabitReminders(); // runs every resume
    _checkCloudSyncOnResume(notifier);
    _pushWidgetData();
  }
}
```

`_rescheduleHabitReminders` loops through all habits and calls `NotificationService.cancelHabitReminder` + `scheduleHabitReminder` for each. For 10 habits with weekly reminders, this is up to 10 × 39 = 390 async cancel/schedule operations on every app resume. This adds measurable latency and can flicker notifications.

**Fix:** Cache a hash of the reminder-relevant fields and only reschedule when the hash changes:
```dart
String? _lastReminderHash;

Future<void> _rescheduleHabitRemindersIfChanged() async {
  final data = ref.read(dataNotifierProvider).valueOrNull;
  if (data == null) return;
  final hash = data.habits
      .where((h) => h.reminderTime != null && h.archivedAt == null)
      .map((h) => '${h.id}|${h.reminderTime}|${h.schedule.name}|${h.scheduleDays}')
      .join(',');
  if (hash == _lastReminderHash) return;
  _lastReminderHash = hash;
  for (final habit in data.habits) {
    if (habit.reminderTime == null || habit.archivedAt != null) continue;
    // ... existing schedule logic ...
  }
}
```
Call `_rescheduleHabitRemindersIfChanged()` instead of `_rescheduleHabitReminders()` in `didChangeAppLifecycleState`. Still call `_rescheduleHabitReminders()` (force full reschedule) after data first loads and after a habit is added/edited.

---

### 🟡 BUG-028 — `SyncService.markUpdated()` uses sub-second precision vs filesystem second-level mtime

**Affected files:**
- `lib/core/services/sync_service.dart`

**Root cause:**
```dart
void markUpdated() => _lastKnownModified = DateTime.now(); // sub-second
```
Some Android filesystems report file mtime at second-level precision. If `markUpdated()` stores `10:00:00.001` and the file write completes with mtime `10:00:01` (rounded up), then `modified.isAfter(_lastKnownModified)` = true → spurious reload. Very rare but possible.

**Fix:** Truncate to second precision:
```dart
void markUpdated() {
  final n = DateTime.now();
  _lastKnownModified = DateTime(n.year, n.month, n.day, n.hour, n.minute, n.second);
}
```

---

## 10. Edge Cases & Fail-Safes

---

### 🟠 BUG-029 — `EntitlementService.checkPro()` crashes the app if Firebase failed to initialise

**Affected files:**
- `lib/core/services/entitlement_service.dart`

**Root cause:** `main.dart` wraps `Firebase.initializeApp()` in a try/catch so the app starts even without Firebase. However, `EntitlementService.checkPro()` calls Firestore directly. If Firebase didn't initialise, this throws an unhandled `FirebaseException` in `AuthNotifier.restore()` → `SplashScreen._init()` catch block → falls back to welcome screen. The app recovers, but Pro status is lost for the session.

**Fix:** Wrap the Firestore call:
```dart
Future<bool> checkPro() async {
  try {
    // ... Firestore call ...
  } on FirebaseException catch (e) {
    debugPrint('[Entitlement] Firebase unavailable: $e');
    return false; // degrade gracefully — no crash, no Pro loss if local says pro
  } catch (_) {
    return false;
  }
}
```

---

### 🟡 BUG-030 — `DataNotifier.reset()` does not cancel pending Drive debounce timer

**Affected files:**
- `lib/core/providers/cloud_sync_provider.dart`, `lib/core/providers/auth_provider.dart`

**Root cause:** When the user signs out, `AuthNotifier.signOut()` calls `DataNotifier.reset()` but does NOT call `CloudSyncNotifier.disableSync()`. If a 5-second debounce timer is pending (triggered by a data save just before sign-out), the timer fires after sign-out. `_doSync` runs with an invalid `googleSignIn` session, catches `DriveServiceException('Not authenticated')`, and sets `SyncStatus.error` on the now-signed-out notifier. This is harmless but leaves the provider in an error state for the next login.

**Fix:** In `AuthNotifier.signOut()`, also call `disableSync()`:
```dart
Future<void> signOut() async {
  // Cancel any pending sync operations before clearing auth.
  // Note: pass ref or inject cloudSyncNotifier if available.
  await _service.signOut();
  state = const AuthState();
}
```
Or call it from the sign-out button handler in `settings_screen.dart`:
```dart
await ref.read(cloudSyncProvider.notifier).disableSync();
await ref.read(authNotifierProvider.notifier).signOut();
```

---

### 🟡 BUG-031 — Counter habits allow up to 2× target with no visual max indicator

**Affected files:**
- `lib/core/providers/data_provider.dart`

**Root cause:**
```dart
final newValue = (existing.value + delta).clamp(0, habit.targetValue * 2);
```
Intentional to allow over-tracking (e.g., logging extra water glasses). However, users who tap past the target see no visual cue that they've gone over or that there is a soft ceiling. The habit tile shows the same "completed" state whether at 100% or 200%.

**Recommendation:** Add a subtle over-target indicator in `habit_check_widget.dart`:
```dart
if (log.value > habit.targetValue)
  Text('+${log.value - habit.targetValue}', style: TextStyle(color: primary, fontSize: 10))
```

---

### 🟡 BUG-032 — `focusSvcProvider` uses `ChangeNotifierProvider` which disposes on screen exit

**Affected files:**
- `lib/features/focus/focus_screen.dart`

**Root cause:**
```dart
final focusSvcProvider = ChangeNotifierProvider<FocusSessionService>(
  (ref) => FocusSessionService(),
);
```
`ChangeNotifierProvider` disposes when its last listener is removed. If the user navigates away from the Focus screen while a timer is running, the `FocusSessionService` is disposed → `_timer.cancel()` is called in `dispose()` → the timer stops silently with no session saved.

`app.dart` watches `focusSvcProvider` globally:
```dart
ref.read(focusSvcProvider).addListener(_onFocusSvcChange);
```
Because `app.dart` keeps a listener alive, the provider is NOT disposed. This works correctly today. But this is a fragile pattern — if `app.dart` ever removes its listener, the timer stops. This should be made explicit.

**Fix:** Add a `keepAlive` ref in the provider to make the intent explicit:
```dart
final focusSvcProvider = ChangeNotifierProvider<FocusSessionService>((ref) {
  ref.keepAlive(); // Timer must survive screen navigation
  return FocusSessionService();
});
```

---

### 🟢 BUG-033 — Guest data file persists after a signed-in user logs in on the same device

**Affected files:**
- `lib/features/auth/welcome_screen.dart`

**Root cause:**
```dart
if (hasGuestData) {
  final confirmed = await _showGuestUpgradeDialog();
  if (!confirmed || !mounted) return;
}
```
The dialog warns that guest data "will remain on this device." After the user signs in with Google, the guest data file (`habitgenius_data.json` in internal documents) still exists. The signed-in user's data uses the same path. On next guest sign-in, the old file is loaded. This is acceptable for the current single-file-path design but should be documented.

**No code fix needed.** Existing behavior is intentional (users can export before signing in). Document in code comments.

---

### 🟢 BUG-034 — `HabitHelpers.allTimeHeatmap` uses `createdAt` from local timezone but compares to UTC string

**Affected files:**
- `lib/core/utils/habit_helpers.dart`

**Root cause:**
```dart
final createdAt = DateTime.tryParse(habit.createdAt)?.toLocal() ?? today;
```
`habit.createdAt` is a UTC ISO string. `DateTime.tryParse` returns a UTC DateTime. `.toLocal()` is called. This is correct. No bug — confirming safe.

---

## 11. Summary Table

| ID | Severity | Module | Issue |
|---|---|---|---|
| BUG-001 | 🔴 Critical | Android Widget | Sunday habits never appear scheduled in widget |
| BUG-002 | 🔴 Critical | Android Widget | specific/custom habits (Weekdays/Weekends/Custom) always appear scheduled |
| BUG-003 | 🔴 Critical | Android Widget | Monthly habits always appear scheduled every day |
| BUG-004 | 🟠 High | Flutter Habits | Weekly view uses Sun–Sat, widget uses Mon–Sun — inconsistent |
| BUG-005 | 🟠 High | Drive Sync | isAuthRevoked misses HTTP 401 / insufficient_scope errors |
| BUG-006 | 🟠 High | Drive Sync | disableSync() race condition overridden by in-flight sync |
| BUG-007 | 🟠 High | Drive Sync | scheduleUpload passes googleSignIn that can be stale post sign-out |
| BUG-008 | 🟠 High | Widget Sync | Focus stats "today" uses UTC-unsafe `startsWith` date comparison |
| BUG-009 | 🟠 High | Widget Sync | Widget data not pushed on initial cold app start |
| BUG-010 | 🟡 Medium | Expense Widget | Shows "Today: -$0.00" when no expenses logged |
| BUG-011 | 🟡 Medium | Expense Widget | Only first account balance shown — no total |
| BUG-012 | 🟡 Medium | Mood Widget | Emoji may render as boxes on API 26 devices |
| BUG-013 | 🟡 Medium | All Widgets | Widget data not cleared on sign-out |
| BUG-014 | 🟡 Medium | Focus Widget | Widget-started sessions always "Deep Work / Pomodoro" |
| BUG-015 | 🟡 Medium | Focus Screen | No indicator when timer runs while on another screen |
| BUG-016 | 🟠 High | Home Screen | Guest users see mood counted in "N done / total" — can't reach 100% |
| BUG-017 | 🟠 High | Onboarding | Folder-picker UI is dead code — resolveFilePath ignores it |
| BUG-018 | 🟡 Medium | Auth | signInWithGoogle can downgrade locally-cached Pro status |
| BUG-019 | 🟠 High | Settings | deleteAccount unhandled requires-recent-login Firebase error |
| BUG-020 | 🟡 Medium | Notifications | Monthly notifications skip months shorter than selected day |
| BUG-021 | 🟡 Medium | Notifications | Notification ID hash collision risk between habits |
| BUG-022 | 🟡 Medium | Notifications | Sunday weekday index 0 may not match zonedSchedule internals |
| BUG-023 | 🟡 Medium | Data Service | rename() may throw on cross-filesystem paths (some OEM devices) |
| BUG-024 | 🟡 Medium | Expenses | "Add account first" toast doesn't switch to Accounts tab |
| BUG-025 | 🟡 Medium | Expenses | No "transactions remaining today" indicator for registered users |
| BUG-026 | 🟡 Medium | Mood | Tag pre-selection in edit flow needs audit |
| BUG-027 | 🟠 High | App Lifecycle | Notification reschedule on every resume (expensive O(N) work) |
| BUG-028 | 🟡 Medium | SyncService | markUpdated() sub-second precision vs filesystem second-level mtime |
| BUG-029 | 🟠 High | Firebase | EntitlementService.checkPro() not crash-safe when Firebase fails |
| BUG-030 | 🟡 Medium | Auth | Drive debounce timer not cancelled on sign-out |
| BUG-031 | 🟡 Medium | Data | Counter 2× target has no visual max indicator |
| BUG-032 | 🟡 Medium | Focus | focusSvcProvider keepAlive not explicit — fragile lifecycle |
| BUG-033 | 🟢 Low | Auth | Guest data persists after sign-in (intentional, needs doc) |
| BUG-034 | 🟢 Low | Habits | allTimeHeatmap createdAt parsing — confirmed safe |

---

## 12. Priority Fix Order

### Phase 1 — Fix First (breaking, affects all users immediately)

| # | Bug | File | What to do |
|---|---|---|---|
| 1 | BUG-001 | `HabitsWidgetActionReceiver.kt` | Remap `isoDow 7 → 0` for Sunday comparison |
| 2 | BUG-002 | `HabitsWidgetActionReceiver.kt` | Add `"specific"`, `"custom"` cases to `isScheduledOn` |
| 3 | BUG-003 | `HabitsWidgetActionReceiver.kt` | Add `"monthly"` case to `isScheduledOn` |
| 4 | BUG-008 | `widget_sync_service.dart` | Parse UTC startedAt → toLocal() for focus stats |
| 5 | BUG-009 | `app.dart` | Push widget data in `_dataSub` on initial load |
| 6 | BUG-016 | `home_screen.dart` | Exclude mood from guest activity count |

### Phase 2 — Fix Next (correctness, affects many users)

| # | Bug | File | What to do |
|---|---|---|---|
| 7 | BUG-005 | `cloud_sync_provider.dart` | Broaden `isAuthRevoked` to cover HTTP 401, scope errors |
| 8 | BUG-006 | `cloud_sync_provider.dart` | Add `_syncCancelled` flag |
| 9 | BUG-013 | `data_provider.dart` | Push `AppData.empty()` in `DataNotifier.reset()` |
| 10 | BUG-017 | Multiple files | Remove dead onboarding folder-picker |
| 11 | BUG-019 | `settings_screen.dart` | Catch `requires-recent-login` in delete-account handler |
| 12 | BUG-027 | `app.dart` | Hash-guard notification reschedule on resume |
| 13 | BUG-029 | `entitlement_service.dart` | Wrap Firestore call in try/catch |
| 14 | BUG-004 | `habit_helpers.dart` | Align `weeklyCompletion` to Monday start |

### Phase 3 — Polish (UX & edge cases)

| # | Bug | What to do |
|---|---|---|
| 15 | BUG-010 | Expense widget: "No expenses" instead of "-$0.00" |
| 16 | BUG-011 | Expense widget: show net total of all accounts |
| 17 | BUG-018 | Auth: preserve local Pro on signInWithGoogle |
| 18 | BUG-020 | Add short-month warning to monthly day picker |
| 19 | BUG-022 | Audit `_nextInstanceOfTime` for Sunday (weekday=0) |
| 20 | BUG-023 | Add cross-device rename fallback in DataService |
| 21 | BUG-024 | Expense FAB: auto-switch to Accounts tab when empty |
| 22 | BUG-030 | Cancel Drive debounce on sign-out |
| 23 | BUG-032 | Add `ref.keepAlive()` to `focusSvcProvider` |

---

*End of review — 34 issues documented across 20+ files.*
*Run `flutter analyze` after each fix phase to catch regressions.*
