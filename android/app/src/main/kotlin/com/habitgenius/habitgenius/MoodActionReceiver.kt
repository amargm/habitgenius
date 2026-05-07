package com.habitgenius

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * Handles quick mood-log taps from the home-screen widget.
 *
 * Receives ACTION_LOG_MOOD with "level" extra (1–5).
 * Creates or replaces today's Mood entry in the data file atomically,
 * re-builds the SharedPreferences snapshot, and refreshes the widget.
 *
 * Input validation: level must be in 1–5; any other value is silently ignored
 * to prevent data corruption.
 *
 * Play Store compliance:
 *  - android:exported="false" (internal broadcast only)
 *  - Atomic rename for data file write
 *  - No network calls
 */
class MoodActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_LOG_MOOD = "com.habitgenius.LOG_MOOD"

        private val MOOD_EMOJIS = arrayOf("😢", "😔", "😐", "😊", "🤩")
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_LOG_MOOD) return

        // Validate level to prevent injection / corrupt data.
        val level = intent.getIntExtra("level", 0)
        if (level !in 1..5) return

        val dataFile = File(context.filesDir, "app_flutter/habitgenius_data.json")
        if (!dataFile.exists()) return

        val root = runCatching { JSONObject(dataFile.readText()) }.getOrNull() ?: return

        val todayStr = todayStr()
        val moods: JSONArray = root.optJSONArray("moods") ?: JSONArray()

        // Find existing mood entry for today (replace if exists).
        var existingIndex = -1
        for (i in 0 until moods.length()) {
            val m = moods.getJSONObject(i)
            if (m.optString("date") == todayStr) { existingIndex = i; break }
        }

        val moodEntry = JSONObject().apply {
            put("id", if (existingIndex >= 0) moods.getJSONObject(existingIndex).optString("id")
                      else UUID.randomUUID().toString())
            put("date", todayStr)
            put("level", level)
            put("emoji", MOOD_EMOJIS[level - 1])
            put("tags", JSONArray())
            put("note", "")
            put("loggedAt", isoNow())
        }

        if (existingIndex >= 0) {
            moods.put(existingIndex, moodEntry)
        } else {
            moods.put(moodEntry)
        }
        root.put("moods", moods)

        val meta = root.optJSONObject("appMeta") ?: JSONObject().also { root.put("appMeta", it) }
        meta.put("lastModified", isoNow())

        // Atomic write.
        val tmp = File(dataFile.parent, "habitgenius_data.json.tmp")
        runCatching {
            tmp.writeText(root.toString())
            if (!tmp.renameTo(dataFile)) {
                dataFile.writeText(root.toString())
                tmp.delete()
            }
        }.onFailure { tmp.delete(); return }

        // Re-build mood SharedPrefs snapshot.
        val updatedJson = buildMoodJson(root, todayStr, level)
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString("flutter.hw_mood", updatedJson)
            .apply()

        // Refresh widget.
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, MoodWidgetProvider::class.java))
        ids.forEach { id -> MoodWidgetProvider.updateWidget(context, manager, id) }
    }

    // ── JSON rebuild ──────────────────────────────────────────────────────────

    private fun buildMoodJson(root: JSONObject, todayStr: String, todayLevel: Int): String {
        val moods = root.optJSONArray("moods") ?: JSONArray()
        val settings = root.optJSONObject("settings")
        val tier = settings?.optString("userTier", "guest") ?: "guest"

        // Collect recent (non-today) mood levels for trend.
        val recentLevels = JSONArray()
        val sorted = mutableListOf<Pair<String, Int>>()
        for (i in 0 until moods.length()) {
            val m = moods.getJSONObject(i)
            val date = m.optString("date")
            if (date != todayStr) sorted.add(date to m.optInt("level", 3))
        }
        sorted.sortByDescending { it.first }
        sorted.take(4).forEach { recentLevels.put(it.second) }

        return JSONObject()
            .put("tier", tier)
            .put("todayLogged", true)
            .put("todayLevel", todayLevel)
            .put("todayEmoji", if (todayLevel in 1..5) MOOD_EMOJIS[todayLevel - 1] else "")
            .put("recentLevels", recentLevels)
            .toString()
    }

    private fun todayStr(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun isoNow(): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(Date())
}
