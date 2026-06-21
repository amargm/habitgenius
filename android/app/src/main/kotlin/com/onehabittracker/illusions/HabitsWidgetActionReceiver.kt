package com.onehabittracker.illusions

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * Handles quick-log taps from the home-screen widget.
 *
 * On each tap it:
 * 1. Reads the data file directly (no Flutter engine needed).
 * 2. Finds or creates the [HabitLog] for today.
 * 3. Applies the appropriate mutation (toggle / increment / set-to-target).
 * 4. Writes the file atomically via a temp-file rename.
 * 5. Re-pushes the updated snapshot to SharedPreferences.
 * 6. Notifies [AppWidgetManager] to redraw the widget.
 */
class HabitsWidgetActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_LOG_HABIT) return

        val habitId = intent.getStringExtra("habitId") ?: return
        val progressType = intent.getStringExtra("progressType") ?: "checkbox"
        val targetValue = intent.getIntExtra("targetValue", 1)

        val dataFile = File(context.filesDir, "app_flutter/onehabittracker_data.json")
        if (!dataFile.exists()) return

        val root = runCatching {
            JSONObject(dataFile.readText())
        }.getOrNull() ?: return

        val todayStr = todayStr()

        // Locate or create the habit log entry.
        val logs: JSONArray = root.optJSONArray("habitLogs") ?: JSONArray()
        var logIndex = -1
        for (i in 0 until logs.length()) {
            val l = logs.getJSONObject(i)
            if (l.optString("habitId") == habitId && l.optString("date") == todayStr) {
                logIndex = i
                break
            }
        }

        val log: JSONObject = if (logIndex >= 0) {
            logs.getJSONObject(logIndex)
        } else {
            JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("habitId", habitId)
                put("date", todayStr)
                put("completed", false)
                put("value", 0)
                put("note", "")
                put("createdAt", isoNow())
            }
        }

        // Apply mutation based on progress type.
        when (progressType) {
            "checkbox", "checklist", "stopwatch" -> {
                log.put("completed", !log.optBoolean("completed"))
            }
            "counter" -> {
                val current = log.optInt("value", 0)
                val next = if (current >= targetValue) 0 else (current + 1)
                log.put("value", next)
                log.put("completed", next >= targetValue)
            }
            "timer" -> {
                val current = log.optInt("value", 0)
                val next = if (current >= targetValue) 0 else targetValue
                log.put("value", next)
                log.put("completed", next >= targetValue)
            }
        }
        log.put("updatedAt", isoNow())

        if (logIndex >= 0) {
            logs.put(logIndex, log)
        } else {
            logs.put(log)
        }
        root.put("habitLogs", logs)

        // Update appMeta.lastModified.
        val meta = root.optJSONObject("appMeta") ?: JSONObject().also { root.put("appMeta", it) }
        meta.put("lastModified", isoNow())

        // Atomic write: write to .tmp then rename.
        val tmp = File(dataFile.parent, "onehabittracker_data.json.tmp")
        try {
            tmp.writeText(root.toString())
            if (!tmp.renameTo(dataFile)) {
                // Rename failed — fall back to direct overwrite.
                dataFile.writeText(root.toString())
                tmp.delete()
            }
        } catch (_: Exception) {
            tmp.delete()
            return
        }

        // Re-push SharedPreferences snapshot.
        val prefs: SharedPreferences = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE,
        )

        // Preserve streak counts from the existing snapshot — streak recalculation
        // happens in Flutter. We carry values forward so the Streak widget stays
        // accurate between app opens.
        val existingStreakMap = mutableMapOf<String, Int>()
        prefs.getString("flutter.hw_widget_habits", null)?.let { existing ->
            runCatching {
                val existingRoot = JSONObject(existing)
                val existingHabits = existingRoot.optJSONArray("habits") ?: return@let
                for (i in 0 until existingHabits.length()) {
                    val h = existingHabits.getJSONObject(i)
                    existingStreakMap[h.optString("id")] = h.optInt("currentStreak", 0)
                }
            }
        }

        val widgetJson = buildWidgetJson(root, existingStreakMap)
        prefs.edit().putString("flutter.hw_widget_habits", widgetJson).apply()

        // Refresh widget.
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, HabitsWidgetProvider::class.java),
        )
        ids.forEach { id ->
            HabitsWidgetProvider.updateWidget(context, manager, id)
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun todayStr(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun isoNow(): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(Date())

    /**
     * Rebuilds the compact widget JSON from the full data root so the widget
     * rows refresh immediately without waiting for Flutter to wake up.
     */
    private fun buildWidgetJson(root: JSONObject, existingStreakMap: Map<String, Int> = emptyMap()): String {
        val habits = root.optJSONArray("habits") ?: JSONArray()
        val logs = root.optJSONArray("habitLogs") ?: JSONArray()
        val todayStr = todayStr()

        // Build 7-day window (Mon–Sun of current ISO week).
        val cal = java.util.Calendar.getInstance(Locale.US).apply {
            firstDayOfWeek = java.util.Calendar.MONDAY
            set(java.util.Calendar.DAY_OF_WEEK, java.util.Calendar.MONDAY)
        }
        val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val weekDates = (0..6).map { i ->
            val d = cal.clone() as java.util.Calendar
            d.add(java.util.Calendar.DAY_OF_MONTH, i)
            fmt.format(d.time)
        }
        val weekLabels = listOf("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")

        // Index logs by "habitId:date" for O(1) lookup.
        val logIndex = mutableMapOf<String, JSONObject>()
        for (i in 0 until logs.length()) {
            val l = logs.getJSONObject(i)
            logIndex["${l.optString("habitId")}:${l.optString("date")}"] = l
        }

        val habitsArr = JSONArray()
        for (i in 0 until habits.length()) {
            val h = habits.getJSONObject(i)
            if (h.optString("archivedAt").isNotEmpty()) continue
            val hId = h.optString("id")
            val pType = h.optString("progressType", "checkbox")
            val target = h.optInt("targetValue", 1)
            val scheduleDays = h.optJSONArray("scheduleDays")
            val schedule = h.optString("schedule", "daily")

            val weekStatus = JSONArray()
            for (dateStr in weekDates) {
                val scheduled = isScheduledOn(h, scheduleDays, schedule, dateStr)
                val log = logIndex["$hId:$dateStr"]
                val value = log?.optInt("value", 0) ?: 0
                val completed = isCompleted(pType, target, log)
                val progress = if (pType == "counter" || pType == "timer") {
                    if (target > 0) value.toDouble() / target else 0.0
                } else {
                    if (completed) 1.0 else 0.0
                }.coerceIn(0.0, 1.0)
                weekStatus.put(
                    JSONObject()
                        .put("scheduled", scheduled)
                        .put("completed", completed)
                        .put("value", value)
                        .put("progress", progress),
                )
            }

            val todayLog = logIndex["$hId:$todayStr"]
            habitsArr.put(
                JSONObject()
                    .put("id", hId)
                    .put("name", h.optString("name"))
                    .put("icon", h.optString("icon"))
                    .put("colorHex", h.optString("colorHex", "#6750A4"))
                    .put("progressType", pType)
                    .put("targetValue", target)
                    .put("unit", h.optString("unit"))
                    .put("scheduledToday", isScheduledOn(h, scheduleDays, schedule, todayStr))
                    .put("todayCompleted", isCompleted(pType, target, todayLog))
                    .put("todayValue", todayLog?.optInt("value", 0) ?: 0)
                    .put("weekStatus", weekStatus)
                    .put("currentStreak", existingStreakMap[hId] ?: 0),
            )
        }

        return JSONObject()
            .put("todayStr", todayStr)
            .put("weekDates", JSONArray(weekDates))
            .put("weekLabels", JSONArray(weekLabels))
            .put("habits", habitsArr)
            .toString()
    }

    private fun isCompleted(progressType: String, targetValue: Int, log: JSONObject?): Boolean {
        if (log == null) return false
        return when (progressType) {
            "checkbox", "checklist", "stopwatch" -> log.optBoolean("completed")
            else -> log.optInt("value", 0) >= targetValue
        }
    }

    /**
     * Mirrors the Dart HabitHelpers.isScheduledOn() logic.
     *
     * schedule: "daily" | "weekly" | "specific" | "custom" | "monthly" | "interval"
     * scheduleDays: JSON array of ints. For day-of-week schedules Flutter uses
     *   0=Sun, 1=Mon … 6=Sat (date.weekday % 7 convention).
     *   For monthly schedules it contains day-of-month values (1–31).
     */
    private fun isScheduledOn(
        habit: JSONObject,
        scheduleDaysArr: JSONArray?,
        schedule: String,
        dateStr: String,
    ): Boolean {
        val date = runCatching {
            SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(dateStr)
        }.getOrNull() ?: return false

        val cal = java.util.Calendar.getInstance(Locale.US).apply { time = date }
        // Java: 1=Sun,2=Mon,…,7=Sat  →  convert to ISO: 1=Mon…7=Sun
        val javaDow = cal.get(java.util.Calendar.DAY_OF_WEEK)
        val isoDow = if (javaDow == java.util.Calendar.SUNDAY) 7 else javaDow - 1
        // Flutter stores scheduleDays with 0=Sun, 1=Mon … 6=Sat (weekday % 7).
        // ISO Sunday is 7; map it to Flutter's 0. All other days match directly.
        val flutterDow = if (isoDow == 7) 0 else isoDow

        return when (schedule) {
            "daily" -> true
            // "weekly"   = user-picked specific days of week
            // "specific" = preset (Weekdays Mon–Fri, Weekends Sat–Sun)
            // "custom"   = custom day-of-week selection
            // All three store their selected days as Flutter 0=Sun…6=Sat ints.
            "weekly", "specific", "custom" -> {
                if (scheduleDaysArr == null || scheduleDaysArr.length() == 0) {
                    true
                } else {
                    (0 until scheduleDaysArr.length()).any { scheduleDaysArr.getInt(it) == flutterDow }
                }
            }
            // "monthly" stores day-of-month values (1–31).
            "monthly" -> {
                val dayOfMonth = cal.get(java.util.Calendar.DAY_OF_MONTH)
                if (scheduleDaysArr == null || scheduleDaysArr.length() == 0) {
                    true
                } else {
                    (0 until scheduleDaysArr.length()).any { scheduleDaysArr.getInt(it) == dayOfMonth }
                }
            }
            "interval" -> {
                val interval = habit.optInt("intervalDays", 1)
                if (interval <= 1) return true
                val startDateStr = habit.optString("startDate", dateStr)
                val startDate = runCatching {
                    SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(startDateStr)
                }.getOrNull() ?: return true
                val diff = ((date.time - startDate.time) / 86_400_000L).toInt()
                diff >= 0 && diff % interval == 0
            }
            else -> true
        }
    }

    companion object {
        const val ACTION_LOG_HABIT = "com.onehabittracker.WIDGET_ACTION"
    }
}
