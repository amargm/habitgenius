package com.habitgenius

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * Handles all focus timer actions from the home-screen widget.
 *
 * Actions handled:
 *   ACTION_FOCUS_START   — begin a new 25-min Pomodoro; schedule tick alarm
 *   ACTION_FOCUS_PAUSE   — record elapsed time; cancel tick alarm
 *   ACTION_FOCUS_RESUME  — recalculate startedAt; schedule tick alarm
 *   ACTION_FOCUS_RESET   — clear state; cancel tick alarm
 *   ACTION_FOCUS_TICK    — fired by AlarmManager every 60s while running;
 *                          checks for session completion; writes FocusSession
 *                          to data file when done; schedules next tick
 *
 * Timer runtime state is stored in "FlutterSharedPreferences" under key
 * "flutter.hw_focus":
 * {
 *   "state":         "idle"|"running"|"paused"|"done",
 *   "mode":          "Pomodoro",
 *   "category":      "Deep Work",
 *   "targetSeconds": 1500,
 *   "startedAt":     epochMillis (long, 0 when not running),
 *   "pausedElapsed": seconds accumulated before last pause,
 *   "completedCycles": 0
 * }
 *
 * Play Store compliance:
 *  - BroadcastReceiver.onReceive() stays well under the 10-second limit
 *    (all operations are synchronous SharedPrefs + file I/O)
 *  - AlarmManager.canScheduleExactAlarms() is checked on API 31+
 *  - Tick alarm uses explicit ComponentName — no implicit broadcast
 *  - All PendingIntents use FLAG_IMMUTABLE
 */
class FocusTimerReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FOCUS_START  = "com.habitgenius.FOCUS_START"
        const val ACTION_FOCUS_PAUSE  = "com.habitgenius.FOCUS_PAUSE"
        const val ACTION_FOCUS_RESUME = "com.habitgenius.FOCUS_RESUME"
        const val ACTION_FOCUS_RESET  = "com.habitgenius.FOCUS_RESET"
        const val ACTION_FOCUS_TICK   = "com.habitgenius.FOCUS_TICK"

        // Default session: 25-min Pomodoro
        private const val DEFAULT_TARGET_SECONDS = 1500
        private const val TICK_INTERVAL_MS = 60_000L
        // Unique request code for the tick alarm PendingIntent
        private const val REQ_TICK = 9901
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_FOCUS_START  -> handleStart(context)
            ACTION_FOCUS_PAUSE  -> handlePause(context)
            ACTION_FOCUS_RESUME -> handleResume(context)
            ACTION_FOCUS_RESET  -> handleReset(context)
            ACTION_FOCUS_TICK   -> handleTick(context)
        }
    }

    // ── Action handlers ──────────────────────────────────────────────────────

    private fun handleStart(context: Context) {
        val prefs = prefs(context)
        val existing = runCatching {
            JSONObject(prefs.getString("flutter.hw_focus", "{}") ?: "{}")
        }.getOrElse { JSONObject() }

        // Only start if idle or done.
        val currentState = existing.optString("state", "idle")
        if (currentState == "running" || currentState == "paused") return

        val now = System.currentTimeMillis()
        val timerState = JSONObject().apply {
            put("state", "running")
            put("mode", "Pomodoro")
            put("category", "Deep Work")
            put("targetSeconds", DEFAULT_TARGET_SECONDS)
            put("startedAt", now)
            put("pausedElapsed", 0L)
            put("completedCycles", existing.optInt("completedCycles", 0))
        }
        prefs.edit().putString("flutter.hw_focus", timerState.toString()).apply()
        scheduleNextTick(context, TICK_INTERVAL_MS)
        notifyWidget(context)
    }

    private fun handlePause(context: Context) {
        val prefs = prefs(context)
        val timer = loadTimer(prefs) ?: return
        if (timer.optString("state") != "running") return

        val startedAt = timer.optLong("startedAt", 0L)
        val previousElapsed = timer.optLong("pausedElapsed", 0L)
        val nowElapsed = previousElapsed + (System.currentTimeMillis() - startedAt) / 1000L

        timer.put("state", "paused")
        timer.put("pausedElapsed", nowElapsed)
        timer.put("startedAt", 0L)
        prefs.edit().putString("flutter.hw_focus", timer.toString()).apply()

        cancelTickAlarm(context)
        notifyWidget(context)
    }

    private fun handleResume(context: Context) {
        val prefs = prefs(context)
        val timer = loadTimer(prefs) ?: return
        if (timer.optString("state") != "paused") return

        timer.put("state", "running")
        timer.put("startedAt", System.currentTimeMillis())
        prefs.edit().putString("flutter.hw_focus", timer.toString()).apply()

        scheduleNextTick(context, TICK_INTERVAL_MS)
        notifyWidget(context)
    }

    private fun handleReset(context: Context) {
        val prefs = prefs(context)
        val timer = loadTimer(prefs)
        val cycles = timer?.optInt("completedCycles", 0) ?: 0

        val reset = JSONObject().apply {
            put("state", "idle")
            put("mode", "Pomodoro")
            put("category", "Deep Work")
            put("targetSeconds", DEFAULT_TARGET_SECONDS)
            put("startedAt", 0L)
            put("pausedElapsed", 0L)
            put("completedCycles", cycles)
        }
        prefs.edit().putString("flutter.hw_focus", reset.toString()).apply()
        cancelTickAlarm(context)
        notifyWidget(context)
    }

    private fun handleTick(context: Context) {
        val prefs = prefs(context)
        val timer = loadTimer(prefs) ?: return
        if (timer.optString("state") != "running") return

        val startedAt = timer.optLong("startedAt", 0L)
        val previousElapsed = timer.optLong("pausedElapsed", 0L)
        val totalElapsed = previousElapsed + (System.currentTimeMillis() - startedAt) / 1000L
        val targetSeconds = timer.optInt("targetSeconds", DEFAULT_TARGET_SECONDS)

        if (totalElapsed >= targetSeconds) {
            // Session complete.
            val cycles = timer.optInt("completedCycles", 0) + 1
            timer.put("state", "done")
            timer.put("pausedElapsed", targetSeconds.toLong())
            timer.put("startedAt", 0L)
            timer.put("completedCycles", cycles)
            prefs.edit().putString("flutter.hw_focus", timer.toString()).apply()

            // Write the completed FocusSession to the data file.
            val sessionDuration = targetSeconds
            saveFocusSessionToFile(context, sessionDuration, timer.optString("category", "Deep Work"))

            // Do NOT schedule next tick — session is over.
        } else {
            // Session still running — schedule next tick.
            val remaining = targetSeconds - totalElapsed
            val nextDelay = minOf(TICK_INTERVAL_MS, remaining * 1000L)
            scheduleNextTick(context, nextDelay)
        }

        notifyWidget(context)
    }

    // ── AlarmManager ─────────────────────────────────────────────────────────

    private fun scheduleNextTick(context: Context, delayMs: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = tickPendingIntent(context)
        val triggerAt = System.currentTimeMillis() + delayMs

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // API 31+: check permission before setExact; fall back to setWindow.
            if (am.canScheduleExactAlarms()) {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                // 30-second window around the target — acceptable for a timer.
                am.setWindow(AlarmManager.RTC_WAKEUP, triggerAt, 30_000L, pi)
            }
        } else {
            // API 26-30: setExact works without special permission.
            am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    private fun cancelTickAlarm(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(tickPendingIntent(context))
    }

    private fun tickPendingIntent(context: Context): PendingIntent {
        val intent = Intent(ACTION_FOCUS_TICK).apply {
            setClass(context, FocusTimerReceiver::class.java)
        }
        return PendingIntent.getBroadcast(
            context, REQ_TICK, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ── Data file write ──────────────────────────────────────────────────────

    /**
     * Writes a completed [FocusSession] directly to the app's JSON data file,
     * using the same atomic-rename strategy as [HabitsWidgetActionReceiver].
     * Safe to call from [BroadcastReceiver.onReceive()].
     */
    private fun saveFocusSessionToFile(context: Context, durationSeconds: Int, category: String) {
        val dataFile = File(context.filesDir, "app_flutter/habitgenius_data.json")
        if (!dataFile.exists()) return

        val root = runCatching { JSONObject(dataFile.readText()) }.getOrNull() ?: return

        val session = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("category", category)
            put("mode", "pomodoro")
            put("plannedDuration", durationSeconds)
            put("actualDuration", durationSeconds)
            put("completedCycles", 1)
            // Compute accurate timestamps: end = now, start = end − duration.
            val endTimeMs = System.currentTimeMillis()
            val startTimeMs = endTimeMs - (durationSeconds * 1000L)
            put("startedAt", isoFormat(startTimeMs))
            put("endedAt", isoFormat(endTimeMs))
        }

        val sessions = root.optJSONArray("focusSessions") ?: JSONArray()
        sessions.put(session)
        root.put("focusSessions", sessions)

        val meta = root.optJSONObject("appMeta") ?: JSONObject().also { root.put("appMeta", it) }
        meta.put("lastModified", isoNow())

        val tmp = File(dataFile.parent, "habitgenius_data.json.tmp")
        runCatching {
            tmp.writeText(root.toString())
            if (!tmp.renameTo(dataFile)) {
                dataFile.writeText(root.toString())
                tmp.delete()
            }
        }.onFailure { tmp.delete() }
    }

    // ── Widget redraw ─────────────────────────────────────────────────────────

    private fun notifyWidget(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, FocusWidgetProvider::class.java),
        )
        ids.forEach { id -> FocusWidgetProvider.updateWidget(context, manager, id) }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun prefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private fun loadTimer(prefs: android.content.SharedPreferences): JSONObject? =
        runCatching {
            JSONObject(prefs.getString("flutter.hw_focus", null) ?: return null)
        }.getOrNull()

    private fun isoNow(): String = isoFormat(System.currentTimeMillis())

    private fun isoFormat(epochMs: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(Date(epochMs))
}
