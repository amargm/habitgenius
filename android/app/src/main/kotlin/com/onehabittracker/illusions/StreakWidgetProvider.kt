package com.onehabittracker.illusions

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Streak Showcase home-screen widget (2×1, resizable to 2×2).
 *
 * Shows the top 3 habits sorted by current streak (descending).
 * Each row: emoji icon · habit name · "X days" · 5 recent-day dot bitmaps.
 * Habits with streak ≥ 7 get a 🔥 suffix on the count.
 * Read-only — the entire widget opens the app; no quick-log here.
 *
 * Data source: "flutter.hw_widget_habits" (same key as the Habits widget;
 * the JSON already includes "currentStreak" per habit after the
 * WidgetSyncService update).
 *
 * Play Store compliance:
 *  - Single launcher PendingIntent on the open button only
 *  - No broadcast PendingIntents (read-only widget)
 *  - exported="true" only for the AppWidgetProvider receiver
 */
class StreakWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { id -> updateWidget(context, appWidgetManager, id) }
    }

    companion object {

        // Per-row view ID groups for the 3 streak rows.
        private val ROW_IDS = intArrayOf(
            R.id.streak_row_0, R.id.streak_row_1, R.id.streak_row_2,
        )
        private val ICON_IDS = intArrayOf(
            R.id.streak_icon_0, R.id.streak_icon_1, R.id.streak_icon_2,
        )
        private val NAME_IDS = intArrayOf(
            R.id.streak_name_0, R.id.streak_name_1, R.id.streak_name_2,
        )
        private val COUNT_IDS = intArrayOf(
            R.id.streak_count_0, R.id.streak_count_1, R.id.streak_count_2,
        )
        // 5 dot ImageViews per row: [row][dot]
        private val DOT_IDS = arrayOf(
            intArrayOf(R.id.streak_dot_0_0, R.id.streak_dot_0_1, R.id.streak_dot_0_2, R.id.streak_dot_0_3, R.id.streak_dot_0_4),
            intArrayOf(R.id.streak_dot_1_0, R.id.streak_dot_1_1, R.id.streak_dot_1_2, R.id.streak_dot_1_3, R.id.streak_dot_1_4),
            intArrayOf(R.id.streak_dot_2_0, R.id.streak_dot_2_1, R.id.streak_dot_2_2, R.id.streak_dot_2_3, R.id.streak_dot_2_4),
        )

        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, StreakWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, StreakWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
        ) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE,
            )
            val raw = prefs.getString("flutter.hw_widget_habits", null)
            val json = raw?.let { runCatching { JSONObject(it) }.getOrNull() }

            val views = RemoteViews(context.packageName, R.layout.widget_streak)

            // Open-app button (only launcher PendingIntent).
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                ?.let {
                    PendingIntent.getActivity(
                        context, 0, it,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                }
                ?.also { views.setOnClickPendingIntent(R.id.streak_open_app, it) }

            val habitsArr = json?.optJSONArray("habits")
            if (habitsArr == null || habitsArr.length() == 0) {
                showEmpty(views, appWidgetManager, widgetId)
                return
            }

            // Parse habits with streak > 0, sort descending.
            data class StreakHabit(
                val icon: String,
                val name: String,
                val colorHex: String,
                val streak: Int,
                val weekStatus: List<Boolean>, // Mon→Sun completed
            )

            val streakHabits = mutableListOf<StreakHabit>()
            for (i in 0 until habitsArr.length()) {
                val h = habitsArr.getJSONObject(i)
                val streak = h.optInt("currentStreak", 0)
                if (streak == 0) continue
                val weekArr = h.optJSONArray("weekStatus")
                val weekCompleted = if (weekArr != null) {
                    (0 until weekArr.length()).map {
                        weekArr.getJSONObject(it).optBoolean("completed")
                    }
                } else emptyList()
                streakHabits.add(
                    StreakHabit(
                        icon = h.optString("icon", "⭐"),
                        name = h.optString("name", ""),
                        colorHex = h.optString("colorHex", "#6750A4"),
                        streak = streak,
                        weekStatus = weekCompleted,
                    ),
                )
            }
            streakHabits.sortByDescending { it.streak }

            if (streakHabits.isEmpty()) {
                showEmpty(views, appWidgetManager, widgetId)
                return
            }

            views.setViewVisibility(R.id.streak_empty_text, View.GONE)

            // Fill up to 3 rows.
            for (row in 0..2) {
                if (row < streakHabits.size) {
                    val habit = streakHabits[row]
                    val accentColor = runCatching { Color.parseColor(habit.colorHex) }
                        .getOrElse { Color.parseColor("#6750A4") }

                    views.setViewVisibility(ROW_IDS[row], View.VISIBLE)
                    views.setTextViewText(ICON_IDS[row], habit.icon)

                    val countLabel = if (habit.streak >= 7) {
                        "${habit.streak}d 🔥"
                    } else {
                        "${habit.streak}d"
                    }
                    views.setTextViewText(NAME_IDS[row], habit.name)
                    views.setTextViewText(COUNT_IDS[row], countLabel)
                    views.setTextColor(COUNT_IDS[row], accentColor)

                    // Show the 5 most recent days up to and including today.
                    // weekStatus is Mon–Sun (7 items); compute today's 0-based index.
                    val cal = java.util.Calendar.getInstance()
                    val javaDow = cal.get(java.util.Calendar.DAY_OF_WEEK)
                    val todayIdx = if (javaDow == java.util.Calendar.SUNDAY) 6 else javaDow - 2
                    val dotsSource = habit.weekStatus
                        .take(todayIdx + 1)   // days Mon..today
                        .takeLast(5)          // at most 5
                    val dots = List(5 - dotsSource.size) { false } + dotsSource
                    for (dot in 0..4) {
                        val completed = dots.getOrElse(dot) { false }
                        val dotBmp = drawDot(context, accentColor, completed)
                        views.setImageViewBitmap(DOT_IDS[row][dot], dotBmp)
                    }
                } else {
                    views.setViewVisibility(ROW_IDS[row], View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        private fun showEmpty(
            views: RemoteViews,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
        ) {
            for (rowId in ROW_IDS) views.setViewVisibility(rowId, View.GONE)
            views.setViewVisibility(R.id.streak_empty_text, View.VISIBLE)
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        // ── Dot bitmap (8dp filled/outlined circle) ──────────────────────────

        private fun drawDot(context: Context, accentColor: Int, completed: Boolean): Bitmap {
            val px = (context.resources.displayMetrics.density * 8).toInt().coerceAtLeast(8)
            val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val cx = px / 2f
            if (completed) {
                paint.style = Paint.Style.FILL
                paint.color = accentColor
            } else {
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = px * 0.15f
                paint.color = Color.argb(70, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor))
            }
            canvas.drawCircle(cx, cx, cx * 0.85f, paint)
            return bmp
        }
    }
}
