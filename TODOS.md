# HabitGenius — Open TODOs

> Update status after each item is completed.
> Status: `[ ]` open · `[~]` in progress · `[x]` done

---

## Home Screen

- [x] **1** Focus weekly status visual: number above day label pushes "W" (Wednesday) up; also gray (unmarked) boxes appear above colored (marked) boxes on the horizontal row — fixed by rendering bar first, label below.
- [x] **2** Mood weekly status visual: unmarked entries show dashes — fixed to use gray boxes (same as other rows).
- [x] **3** Habits weekly status calculation — now filters habits by `createdAt` so days before a habit existed are not counted as missed.
- [x] **4** "X/N done" counter in Today section: mood entry is now counted as +1 activity (total = habits + 1; done increments when today's mood is logged).
- [x] **15** Home username: "HabitGenius" title replaced with the signed-in user's first name.
- [x] **10** Notification bell icon removed from home header.
- [x] **11** Settings avatar: gradient removed, now uses solid primary color.
- [x] **16** Light mode: `+` FAB icon now always readable — `floatingActionButtonTheme` added to `AppTheme` with `foregroundColor = onPrimary`.

---

## Habits Screen

- [x] **13** Default selected filter is now **"All"**. Filter order: `All · Today · This week · Yearly · Archive`.
- [x] **14** Haptic celebration on habit completion. 3-pulse `HapticFeedback` sequence fires when a habit transitions to complete (both from `HabitCheckWidget` and the home-screen today row). Configurable via **Settings → General → Celebration haptic** toggle (default: on).
- [x] **19** Habit templates: tapping "New Habit" shows a bottom sheet with 16 pre-built templates (name, emoji, colour pre-filled). User must choose progress type (mandatory). "Start from scratch" option preserved.

---

## Mood Screen

- [x] **5** Yearly vertical mood calendar: new "Year" tab (3rd tab) in Mood screen — shows Jan–Dec month grid with colour-coded mood cells and prev/next year nav arrows.

---

## Focus Screen

- [x] **6** Focus auto-save: timer auto-saves on completion. Removed redundant "Save" button from finished state.

---

## Journal / Notes Screen

- [x] **7.1** Dark mode: double border fixed — uses `context.appColors.border` (theme-adaptive) and `filled: false`.
- [x] **7.2** Note toolbar now placed inside body Column, floats above keyboard when open.
- [x] **7.3** Markdown preview: preview toggle button (👁 icon) added to journal entry AppBar. Preview mode renders `# headings`, `**bold**`, `*italic*`, `` `code` ``, `~~strikethrough~~`, `- bullets`, `1. numbered lists`, `> blockquotes`, and `---` dividers using a custom inline parser (no extra package needed).

---

## Expenses Screen

- [x] **8** Timeline tab added (3rd tab after Accounts): shows month-by-month expense/income bar visualization, newest months first, with auto-formatted amounts (e.g. `1.4k`), net value, and colour-coded bars.

---

## Onboarding / First Login

- [x] **9** First-login skeleton fix: `onboarding_screen._finish()` now calls `dataNotifierProvider.load()` before navigating to home, so home screen populates immediately after first Google sign-in.
- [x] **9.1** Empty home CTA: when a user has no habits, a `_FirstHabitCta` card is shown in the home screen body ("🌱 Start your journey" + "Add first habit" button navigating to Habits).

---

## Settings / Splash

- [x] **12** Splash screen logo: gradient removed, now uses solid primary color.

---

## Heatmap Overlay (Press & Hold on habit card)

- [x] **17.1** Heading in overlay was too low — overlay uses `LayoutBuilder` so all 12 months fit on screen without scrolling.
- [x] **17.2** Horizontal swipe inside overlay no longer changes the bottom nav tab.
- [x] **17.3** Overlay heatmap now shows Jan–Dec of the current year.

---

## Journal Entry / Nav Bar

- [x] **18** Journal entry screen: tapping a nav bar item pops any open fullscreen entry before navigating.

---

## App-wide

- [x] **20** Toast messages: all `showSnackBar` calls replaced with `AppToast.show()` helper (1.8 s, floating pill, type-specific icons: info / success / error). `SnackBarThemeData` added to `AppTheme`.
- [x] **21** Bug fixes: duplicate `_FirstHabitCta` class removed; `flutter analyze` clean across all files.

---

## New — May 2026 (Batch 4)

- [ ] **22** Focus auto-save works only if Focus screen is open when timer completes — fix so auto-save fires from the background service regardless of screen visibility.
- [ ] **23** Journal entry: rounded corners for title field and tags input area.
- [ ] **24** Mood yearly heatmap: show actual mood emoji in each day cell instead of a solid colour block.
- [ ] **24.1** Home screen: press-and-hold on the Mood weekly row shows the yearly mood heatmap (same behaviour as habit heatmap overlay).
- [ ] **25** Home screen Today section: always show mood tracker row even when user has zero habits (first-time user).
- [ ] **25.1** Home screen CTA (first habit): "Add first habit" button should open the new-habit form directly (not redirect to Habits screen then require another tap).
- [ ] **26** Habits progress types: fully implement Counter, Timer, and Checklist interactions. Remove Stopwatch as a progress type option. Update home-screen Today row to support inline Counter/Timer/Checklist actions.
- [ ] **27** Habit heatmap overlay: background must be fully opaque (zero transparency).
- [ ] **28** Expense Timeline tab: add a line/bar chart with time-period filter chips (Week / Month / Quarter / Year, default Month) above the existing list.
- [ ] **29** Home screen "This Week" section: tapping a weekly status rectangle expands it to a 4-week monthly heatmap; tapping again collapses it. Togglable per habit row.

---

