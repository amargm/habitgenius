# HabitGenius — Open TODOs

> Update status after each item is completed.
> Status: `[ ]` open · `[~]` in progress · `[x]` done

---

## Home Screen

- [ ] **1** Focus weekly status visual: number above day label pushes "W" (Wednesday) up; also gray (unmarked) boxes appear above colored (marked) boxes on the horizontal row — fix layout/alignment.
- [ ] **2** Mood weekly status visual: unmarked entries show dashes while all other rows show gray boxes — unify to boxes everywhere.
- [ ] **3** Habits weekly status calculation — review for correctness and edge cases (e.g. habit created mid-week, timezone rollover, archived habits).
- [ ] **4** "X/N done" counter in Today section: mood entry is not counted as an activity — include it in the denominator and check it off when today's mood is logged.
- [ ] **15** Remove "HabitGenius" text below the greeting; replace it with the signed-in user's display name at the same text size.
- [ ] **10** Remove the notification bell icon next to the settings icon.
- [ ] **11** Remove gradient color from the settings icon; use default accent color or a contrasting solid color.
- [ ] **16** Light mode: the "+" FAB/button has low-contrast symbol — fix so the icon is clearly visible.

---

## Habits Screen

- [ ] **13** Default selected filter should be **"All"** (currently "Today"). Reorder filters to: `All · Today · This week · Yearly · Archive`.
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

- [ ] **12** Splash screen: change logo color to be consistent with updated accent/branding.

---

## Heatmap Overlay (Press & Hold on habit card)

- [ ] **17.1** Heading in the press-and-hold yearly heatmap overlay sits too low, pushing months below the visible area — fit all months on screen without scrolling.
- [ ] **17.2** Horizontal swipe gesture inside the overlay changes the bottom nav tab — disable horizontal swipe while the overlay is open; only back arrow or bottom nav taps should dismiss/navigate.
- [ ] **17.3** The overlay yearly heatmap should always show Jan–Dec (same logic as the expanded habit screen), not a rolling 365-day window.

---

## Journal Entry / Nav Bar

- [ ] **18** Opening a journal entry then tapping another bottom nav item: the nav item highlights but the journal entry screen stays visible — fix so navigation actually closes the entry and goes to the tapped screen.

---

## Done

<!-- Move completed items here -->
