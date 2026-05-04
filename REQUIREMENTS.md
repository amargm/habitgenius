# HabitGenius — Product Requirements Document

**Version:** 1.1  
**Date:** May 4, 2026  
**Status:** Final

---

## 1. Product Overview

HabitGenius is a personal productivity Android application combining habit tracking, mood logging, focus timer, journaling, and expense management into a single unified experience. All user data is stored in a single structured JSON file on the device, with optional cloud sync via user-selected cloud storage (e.g., Google Drive folder).

---

## 2. User Tiers

| Feature | Guest | Registered (Free) | Pro |
|---|---|---|---|
| **Login required** | No | Google Sign-In | Google Sign-In |
| **Data storage** | Local only | User-selected location | User-selected location |
| **Cloud sync** | — | Yes (via file location) | Yes (via file location) |
| **Habits** | 1 | 3 max | Unlimited |
| **Mood tracking** | No | Yes | Yes |
| **Expenses** | No | 4 per day max | Unlimited |
| **Journal notes** | 5 total max | 30 total max | Unlimited |
| **Focus timer** | Yes | Yes | Yes |
| **Color themes** | None (default only) | 5 of 10 colors | All 10 colors |
| **Onboarding** | Skipped (quick start) | Full onboarding | Full onboarding |

---

## 3. Screens & Navigation

### 3.1 Splash Screen
- App logo + name displayed for 1.5–2 seconds
- Checks existing session: routes to Auth or Main App accordingly
- Loads saved theme color before rendering (no flash of wrong color)

### 3.2 Auth / Welcome Screen
Two entry points:
- **Continue as Guest** — no account required, instant access with Guest tier limits applied
- **Sign in with Google** — standard Google OAuth via `google_sign_in` package

First-time Google sign-in triggers the **Data File Setup** flow:  
User selects the folder where their data JSON file will be stored (local storage or a cloud-synced folder such as Google Drive, Dropbox, etc.). This path is saved to `SharedPreferences`.

**Guest upgrade behaviour:** When a Guest user signs in with Google, their local Guest data is **not** automatically migrated. The app displays a clear notice:
> *"Signing in will start fresh with a new data file. Your Guest data will remain on this device but will not carry over. You can manually export it from Settings if needed."*

Guest data stays in internal storage and is not deleted — the user simply starts a new Registered profile.

### 3.3 Onboarding (Registered + Pro only, shown once)
Three slides:
1. What the app does (overview)
2. How data is stored (local file, user controls it)
3. How to set up cloud sync (pick a folder)

### 3.4 Main App — Bottom Navigation
Six tabs (some hidden/locked for Guest):

| Tab | Guest | Registered | Pro |
|---|---|---|---|
| Home | ✓ | ✓ | ✓ |
| Habits | ✓ | ✓ | ✓ |
| Mood | — (hidden) | ✓ | ✓ |
| Focus | ✓ | ✓ | ✓ |
| Journal | ✓ | ✓ | ✓ |
| Money | — (hidden) | ✓ | ✓ |

### 3.5 Settings / Profile Screen
Accessible from Home screen header avatar.

| Setting | Guest | Registered | Pro |
|---|---|---|---|
| Display name & avatar | — | ✓ | ✓ |
| App color theme | — | 5 of 10 | All 10 |
| Dark / Light mode | ✓ | ✓ | ✓ |
| Data file location | — | ✓ | ✓ |
| Manual sync (push/pull) | — | ✓ | ✓ |
| Export backup | — | ✓ | ✓ |
| Import backup | — | ✓ | ✓ |
| Notification settings | ✓ | ✓ | ✓ |
| Currency & region | — | ✓ | ✓ |
| Upgrade to Pro | ✓ (prominent) | ✓ | — |
| Sign out / Switch account | — | ✓ | ✓ |

---

## 4. Feature Requirements

---

### 4.1 Home Screen

**All tiers:**
- Greeting with user name and current date
- Summary stats grid:
  - Habits done today (e.g., "1/1" for Guest, "2/3" for Registered)
  - Current day streak (habit streak)
  - Focus time today
  - Mood today (hidden for Guest — replaced with upgrade prompt card)
- Today's Habits list (limited by tier)
- Quick Actions grid (only shows actions available to current tier)
- AI-style insight card (static for Guest, dynamic for Registered/Pro)

**Upgrade prompt:**  
Guest users see a subtle "Unlock more" banner card on Home that lists what they're missing.

---

### 4.2 Habits

#### 4.2.1 Habit Limits
| Tier | Max habits |
|---|---|
| Guest | 1 |
| Registered | 3 |
| Pro | Unlimited |

Attempting to add beyond the limit shows an upgrade prompt sheet.

#### 4.2.2 Habit Progress Types
- **Checkbox** — simple done/not done
- **Counter** — tap to increment (e.g., glasses of water: 5/8)
- **Timer** — counts down from a set duration
- **Stopwatch** — counts up, user marks done manually
- **Checklist** — sub-tasks within a habit

All types available to all tiers (within their habit count limit).

#### 4.2.3 Habit Properties
- Name
- Icon (emoji, from a picker)
- Color tag
- Progress type (see above)
- Schedule: Daily / Weekly / Specific Days / Monthly / Custom
- Optional reminder (push notification at set time)
- Target value (for Counter/Timer types)

#### 4.2.4 Habit Views
- **Today** — list of today's habits with progress controls
- **This Week** — bar chart of completion per day
- **Monthly** — grid calendar view of completion
- **All** — full list of all habits

#### 4.2.5 Streak Logic
- Streak increments if habit completed on the scheduled day
- Streak resets to 0 if a scheduled day is missed
- Streak persists across app reinstalls (stored in data file)

#### 4.2.6 Yearly Heatmap
- 365-day grid showing completion density (levels 0–4)
- Color intensity based on `--primary` color theme

---

### 4.3 Mood Tracking

**Available to:** Registered, Pro only  
Guest sees a locked/blurred placeholder with upgrade CTA.

#### 4.3.1 Daily Mood Entry
- One mood log per day (can be updated until midnight)
- 5 mood levels: Awful 😢 / Bad 😔 / Meh 😐 / Good 😊 / Great 🤩
- Tags (multi-select): Work, Family, Exercise, Sleep, Health, Finance, Love, Hobbies, Weather, Learning
- Optional short note (plain text, max 280 characters)

#### 4.3.2 Mood Calendar
- Monthly grid showing mood emoji per day
- Tap a day to view or edit that day's entry

#### 4.3.3 Mood Trends
- Last 30 days: % positive days, most common mood
- Insight card: detects correlation between habits and mood (e.g., "You feel better on days you exercise")

---

### 4.4 Focus Timer

**Available to:** All tiers (no restrictions)

#### 4.4.1 Session Setup
- Session category: Work / Study / Creative / Coding / Reading / Writing (user can add custom for Registered/Pro)
- Preset durations: 25 min / 45 min / 60 min
- Custom duration (Registered/Pro only — Guest locked to presets)

#### 4.4.2 Timer Modes
- **Pomodoro** — focus + break cycles
- **Countdown** — simple countdown from set duration
- **Stopwatch** — free-running, user stops when done

#### 4.4.3 Timer Controls
- Play / Pause / Reset / Skip
- Animated circular progress ring
- Session persists through screen lock (foreground service notification)

#### 4.4.4 Session Log
- Each completed session saved: category, duration, start time, date
- Daily / Weekly totals shown on Focus screen and Home

---

### 4.5 Journal

#### 4.5.1 Entry Limits
| Tier | Max journal entries |
|---|---|
| Guest | 5 total |
| Registered | 30 total (active at any time) |
| Pro | Unlimited |

Attempting to create beyond limit shows upgrade prompt.  
Guest: oldest entries are NOT auto-deleted — limit enforced at creation time.  
**Registered deletion rule:** The 30-entry limit is based on current active entries. Deleting an entry immediately frees a slot — the user can create a new entry right away without waiting or upgrading.

#### 4.5.2 Journal Entry Properties
- Title (optional)
- Body text (rich text: bold, italic, underline, headings, bullet/numbered lists)
- Tags (multi-select from preset + custom for Registered/Pro)
- Date/time (auto-set to now, editable)
- Mood link (auto-populated from that day's mood log if available)

#### 4.5.3 Journal Views
- **List** — chronological, most recent first
- **Filter by tag** — chip row filter
- Search by keyword (Registered/Pro only)

#### 4.5.4 Writing Toolbar
Bold / Italic / Underline / Heading / Bullet list / Numbered list / Image attach (Registered/Pro) / Attachment (Registered/Pro) / Color highlight (Pro only)

---

### 4.6 Expenses (Money)

**Available to:** Registered, Pro only  
Guest sees a locked screen with upgrade CTA.

#### 4.6.1 Transaction Limits
| Tier | Max transactions |
|---|---|
| Registered | 4 per day |
| Pro | Unlimited |

When Registered user hits 4 for the day, adding more shows upgrade prompt.  
**Daily limit reset:** The 4-transaction-per-day limit resets at **midnight device local time**. The transaction count is calculated by counting entries where `date == today` in device local timezone.

#### 4.6.2 Transaction Properties
- Type: Expense / Income / Transfer
- Amount (supports user's selected currency)
- Category (preset + custom for Pro):  
  Food, Transport, Shopping, Housing, Health, Entertainment, Education, Other
- Account (user-defined accounts, e.g., "Main Checking", "Credit Card")
- Date/time (default: now, editable)
- Note (optional, plain text)
- Recurring flag (Registered/Pro): Daily / Weekly / Monthly

#### 4.6.3 Accounts
| Tier | Max accounts |
|---|---|
| Registered | 2 |
| Pro | Unlimited |

Account properties: name, type (checking/savings/credit/cash), starting balance, currency.

#### 4.6.4 Views
- **Transactions** — grouped by day, running total
- **Analytics** — pie chart by category, monthly bar chart income vs expense
- **Budget** — set monthly spending limits per category, shows usage bar (Pro feature shown as locked for Registered)

#### 4.6.5 Balance Summary Card
- Total balance across all accounts
- Income vs Expenses for current month
- Color-coded (income = `--success`, expense = `--danger`)

---

## 5. Data Architecture

### 5.1 Storage Strategy

| Tier | Storage |
|---|---|
| Guest | App internal storage only (`getApplicationDocumentsDirectory()`) |
| Registered | User-selected folder path (local or cloud-synced folder via SAF) |
| Pro | User-selected folder path (local or cloud-synced folder via SAF) |

The data file is a single human-readable JSON file: `habitgenius_data.json`

### 5.2 JSON Schema

```json
{
  "meta": {
    "version": 1,
    "appVersion": "1.0.0",
    "createdAt": "ISO8601",
    "lastModified": "ISO8601",
    "deviceId": "uuid"
  },
  "settings": {
    "userTier": "guest | free | pro",
    "displayName": "string",
    "avatarInitials": "string",
    "primaryColorHex": "#6C5CE7",
    "themeMode": "dark | light | system",
    "currency": "USD",
    "currencySymbol": "$",
    "locale": "en_US",
    "dataFilePath": "string | null",
    "notificationsEnabled": true
  },
  "habits": [
    {
      "id": "uuid",
      "name": "string",
      "icon": "emoji",
      "colorHex": "string",
      "progressType": "checkbox | counter | timer | stopwatch | checklist",
      "targetValue": 1,
      "unit": "string | null",
      "schedule": "daily | weekly | monthly | specific | custom",
      "scheduleDays": [0,1,2,3,4],
      "reminderTime": "HH:mm | null",
      "createdAt": "ISO8601",
      "archivedAt": "ISO8601 | null",
      "checklistItems": ["string"]
    }
  ],
  "habitLogs": [
    {
      "id": "uuid",
      "habitId": "uuid",
      "date": "YYYY-MM-DD",
      "completed": true,
      "value": 1,
      "completedAt": "ISO8601 | null"
    }
  ],
  "moods": [
    {
      "id": "uuid",
      "date": "YYYY-MM-DD",
      "level": 1,
      "emoji": "😊",
      "tags": ["Work", "Exercise"],
      "note": "string | null",
      "loggedAt": "ISO8601"
    }
  ],
  "focusSessions": [
    {
      "id": "uuid",
      "category": "string",
      "mode": "pomodoro | countdown | stopwatch",
      "plannedDuration": 1500,
      "actualDuration": 1480,
      "completedCycles": 1,
      "startedAt": "ISO8601",
      "endedAt": "ISO8601"
    }
  ],
  "journal": [
    {
      "id": "uuid",
      "title": "string | null",
      "body": "string",
      "tags": ["string"],
      "linkedMoodId": "uuid | null",
      "createdAt": "ISO8601",
      "updatedAt": "ISO8601"
    }
  ],
  "accounts": [
    {
      "id": "uuid",
      "name": "string",
      "type": "checking | savings | credit | cash",
      "startingBalance": 0.00,
      "currency": "USD",
      "createdAt": "ISO8601"
    }
  ],
  "transactions": [
    {
      "id": "uuid",
      "type": "expense | income | transfer",
      "amount": 14.50,
      "currency": "USD",
      "category": "string",
      "accountId": "uuid",
      "toAccountId": "uuid | null",
      "note": "string | null",
      "recurring": false,
      "recurringInterval": "daily | weekly | monthly | null",
      "date": "YYYY-MM-DD",
      "createdAt": "ISO8601"
    }
  ]
}
```

### 5.3 Sync Strategy
- **Read on launch:** App reads JSON file from stored path into memory
- **Write on change:** Any data mutation immediately writes full JSON back to file
- **External change detection:** On app foreground, compare file `lastModified` timestamp — if newer than last read, reload
- **Conflict resolution:** Last-write-wins based on `lastModified` timestamp
- **Guest:** No sync, internal storage path only, no path picker shown

---

## 6. Theming

### 6.1 Color Themes

10 available preset colors (mapped to `--primary`, `--primary-light`, `--primary-dark`):

| # | Name | Primary Hex | Available to |
|---|---|---|---|
| 1 | Violet (default) | `#6C5CE7` | All tiers |
| 2 | Ocean | `#0984E3` | Registered (1 of 5), Pro |
| 3 | Mint | `#00B894` | Registered (2 of 5), Pro |
| 4 | Coral | `#E17055` | Registered (3 of 5), Pro |
| 5 | Gold | `#FDCB6E` | Registered (4 of 5), Pro |
| 6 | Rose | `#E84393` | Registered (5 of 5), Pro |
| 7 | Sky | `#74B9FF` | Pro only |
| 8 | Lime | `#55EFC4` | Pro only |
| 9 | Peach | `#FAB1A0` | Pro only |
| 10 | Slate | `#636E72` | Pro only |

Colors 7–10 are shown in Settings but grayed out for Registered users with an upgrade CTA.  
Guest sees only the default Violet with no picker shown.

### 6.2 Theme Modes
- Dark (default)
- Light
- System (follows device setting)

Available to all tiers.

---

## 7. Notifications

| Notification type | Guest | Registered | Pro |
|---|---|---|---|
| Habit reminder (scheduled) | ✓ | ✓ | ✓ |
| Focus session end alert | ✓ | ✓ | ✓ |
| Journal streak reminder | — | ✓ | ✓ |
| Daily summary | — | ✓ | ✓ |

Notifications use `flutter_local_notifications`. No server-side push required.

---

## 8. Upgrade / Monetization

### 8.1 Upgrade Prompts
Shown at these moments:
- Guest tries to add a 2nd habit
- Guest tries to create a 6th journal entry
- Guest taps Mood or Money tabs (locked)
- Registered user tries to add a 4th habit
- Registered user tries to add a 5th expense in a day
- Registered user tries to create a 31st journal entry
- Registered user taps a locked color theme

Prompt style: bottom sheet with brief feature summary and "Upgrade to Pro" button.

### 8.2 Pricing Model
- **Free tier:** Registered (Google sign-in, no payment required)
- **Pro tier:** One-time in-app purchase (lifetime unlock, no recurring charge)
- Implemented via Google Play Billing Library (`in_app_purchase` Flutter package)
- Purchase is tied to the Google Play account — user can restore purchase on reinstall or new device via "Restore Purchase" option in Settings

---

## 9. Non-Functional Requirements

| Requirement | Target |
|---|---|
| App launch to Home | < 1.5 seconds |
| File read/write (data sync) | < 300ms for files up to 5MB |
| Minimum Android version | Android 8.0 (API 26) |
| Offline-first | All features work offline; sync happens when file is accessible |
| Accessibility | Minimum WCAG AA contrast ratios; font scaling support |
| Data privacy | No data sent to any server; all data stays in user's chosen file |
| App size | < 30MB installed |

---

## 10. Out of Scope (v1.0)

- iOS support (planned for v2.0)
- Widget (home screen) — planned
- Apple Sign-In
- Multiple profiles / family sharing
- AI-generated insights (static rules only in v1)
- In-app browser for cloud storage — user manages this via their own Drive/Dropbox app
- Recurring transaction auto-creation — planned for v1.1

---

## 11. Decisions Log

| # | Question | Decision | Date |
|---|---|---|---|
| 1 | Pro pricing model | One-time purchase (lifetime) via Google Play Billing | May 4, 2026 |
| 2 | Guest data migration on upgrade | No migration — user shown a notice, Guest data stays in internal storage | May 4, 2026 |
| 3 | Journal slot freed on deletion | Yes — deleting an entry immediately frees a slot for Registered users | May 4, 2026 |
| 4 | Expense daily limit reset time | Midnight device local time | May 4, 2026 |
| 5 | App name | **HabitGenius** — final | May 4, 2026 |
