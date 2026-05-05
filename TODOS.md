# HabitGenius — Open TODOs

> Update status after each item is completed.
> Status: `[ ]` open · `[~]` in progress · `[x]` done

---

## Home Screen

- [x] **1** Focus weekly status visual: number above day label pushes "W" (Wednesday) up; also gray (unmarked) boxes appear above colored (marked) boxes on the horizontal row — fixed by rendering bar first, label below.
- [x] **2** Mood weekly status visual: unmarked entries show dashes — fixed to use gray boxes (same as other rows).
- [ ] **3** Habits weekly status calculation — review for correctness and edge cases (e.g. habit created mid-week, timezone rollover, archived habits).
- [x] **4** "X/N done" counter in Today section: mood entry is now counted as +1 activity (total = habits + 1; done increments when today's mood is logged).
- [x] **15** Home username: "HabitGenius" title replaced with the signed-in user's first name.
- [x] **10** Notification bell icon removed from home header.
- [x] **11** Settings avatar: gradient removed, now uses solid primary color.
- [ ] **16** Light mode: the "+" FAB/button has low-contrast symbol — fix so the icon is clearly visible.

---

## Habits Screen

- [x] **13** Default selected filter is now **"All"**. Filter order: `All · Today · This week · Yearly · Archive`.
- [ ] **14** Haptic + sound feedback (celebration) on completion of each today habit. Sound configurable in Settings (default: enabled).

---

## Mood Screen

- [ ] **5** Yearly vertical mood calendar (Jan–Dec of current year, with prev/next year arrows) — add as a tab beside the existing calendar tab, same navigation pattern as the habit yearly heatmap.

---

## Focus Screen

- [ ] **6** Auto-save timer/stopwatch session on completion — no save/discard prompt; log it automatically.

---

## Journal / Notes Screen

- [ ] **7.1** Dark mode: square + round border both visible in note entry — fix to single rounded design consistent across light and dark modes.
- [ ] **7.2** Note toolbar must remain visible when the keyboard is open (currently may be hidden).
- [ ] **7.3** Review markdown rendering: bold, heading, etc. applied via toolbar buttons add raw syntax characters but text is not rendered as formatted — either render markdown live or clearly indicate the mode (raw vs preview).

---

## Expenses Screen

- [ ] **8** Add more visualizations to the expanded expense view: month-wise breakdown, and/or a dedicated "Time Visualization" tab after the Accounts tab.

---

## Onboarding / First Login

- [ ] **9** After first Google sign-in, home screen shows skeleton UI; habits cannot be added. App must be restarted for full UI to load — fix data initialization so home screen populates without restart.
- [ ] **9.1** After landing on home screen (no habits yet), give the user a clear call-to-action / direction on what to do next (e.g. "Add your first habit" empty state prompt).

---

## Settings / Splash

- [x] **12** Splash screen logo: gradient removed, now uses solid primary color.

---

## Heatmap Overlay (Press & Hold on habit card)

- [x] **17.1** Heading in overlay was too low — overlay now uses `LayoutBuilder` to compute aspect ratio so all 12 months fit on screen without scrolling.
- [x] **17.2** Horizontal swipe inside overlay no longer changes the bottom nav tab — overlay wrapped in `GestureDetector` that absorbs drag gestures.
- [x] **17.3** Overlay heatmap now shows Jan–Dec of the current year (not a rolling 365-day window).

---

## Journal Entry / Nav Bar

- [ ] **18** Opening a journal entry then tapping another bottom nav item: the nav item highlights but the journal entry screen stays visible — fix so navigation actually closes the entry and goes to the tapped screen.

---

## Done

<!-- Move completed items here -->
