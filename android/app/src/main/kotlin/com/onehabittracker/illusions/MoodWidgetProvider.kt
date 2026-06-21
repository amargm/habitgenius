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
import android.graphics.Typeface
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Mood Check-In home-screen widget (2×1).
 *
 * Shows five emoji tap buttons when no mood has been logged today.
 * Shows today's logged mood + 4-day trend dots after logging.
 * Guests see a "Sign in" prompt.
 *
 * Data source: SharedPreferences key "flutter.hw_mood"
 * Quick-log action: broadcasts [MoodActionReceiver.ACTION_LOG_MOOD] with
 * "level" extra (1–5).
 *
 * Play Store compliance:
 *  - Only the open-app ImageButton uses a launcher PendingIntent
 *  - Mood log buttons use FLAG_IMMUTABLE broadcast PendingIntents
 *  - exported="false" for [MoodActionReceiver]
 */
class MoodWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { id -> updateWidget(context, appWidgetManager, id) }
    }

    companion object {

        // Mood level metadata (level 1–5).
        private val MOOD_EMOJIS  = arrayOf("😢", "😔", "😐", "😊", "🤩")
        private val MOOD_LABELS  = arrayOf("Awful", "Bad", "Okay", "Good", "Great")
        private val MOOD_COLORS  = intArrayOf(
            Color.parseColor("#E17055"), // 1 awful  – red
            Color.parseColor("#FDAA6E"), // 2 bad    – orange
            Color.parseColor("#8E8EA0"), // 3 okay   – grey
            Color.parseColor("#00B894"), // 4 good   – green
            Color.parseColor("#6C5CE7"), // 5 great  – purple
        )

        private val PROMPT_BTN_IDS = intArrayOf(
            R.id.mood_btn_1, R.id.mood_btn_2, R.id.mood_btn_3,
            R.id.mood_btn_4, R.id.mood_btn_5,
        )
        private val TREND_IDS = intArrayOf(
            R.id.mood_trend_0, R.id.mood_trend_1,
            R.id.mood_trend_2, R.id.mood_trend_3,
        )

        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, MoodWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, MoodWidgetProvider::class.java).apply {
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
            val raw = prefs.getString("flutter.hw_mood", null)
            val json = raw?.let { runCatching { JSONObject(it) }.getOrNull() }

            val views = RemoteViews(context.packageName, R.layout.widget_mood)

            // Open-app button.
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                ?.let {
                    PendingIntent.getActivity(
                        context, 0, it,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                }
                ?.also { views.setOnClickPendingIntent(R.id.mood_open_app, it) }

            val tier = json?.optString("tier", "guest") ?: "guest"

            if (json == null) {
                // No data has been pushed from the app yet — show a neutral
                // loading state (NOT the "sign in" copy, which only applies
                // to confirmed guests).
                views.setViewVisibility(R.id.mood_panel_prompt, View.GONE)
                views.setViewVisibility(R.id.mood_panel_logged, View.GONE)
                views.setViewVisibility(R.id.mood_locked_text, View.VISIBLE)
                views.setTextViewText(R.id.mood_locked_text, "Open app to load data")
                views.setTextViewText(R.id.mood_title, "Mood")
                appWidgetManager.updateAppWidget(widgetId, views)
                return
            }

            if (tier == "guest") {
                // Confirmed guest — show the sign-in prompt.
                views.setViewVisibility(R.id.mood_panel_prompt, View.GONE)
                views.setViewVisibility(R.id.mood_panel_logged, View.GONE)
                views.setViewVisibility(R.id.mood_locked_text, View.VISIBLE)
                views.setTextViewText(R.id.mood_locked_text, "Sign in for mood tracking")
                views.setTextViewText(R.id.mood_title, "Mood")
                appWidgetManager.updateAppWidget(widgetId, views)
                return
            }

            views.setViewVisibility(R.id.mood_locked_text, View.GONE)

            val todayLogged = json?.optBoolean("todayLogged", false) ?: false

            if (!todayLogged) {
                // Prompt panel: 5 emoji buttons.
                views.setViewVisibility(R.id.mood_panel_prompt, View.VISIBLE)
                views.setViewVisibility(R.id.mood_panel_logged, View.GONE)
                views.setTextViewText(R.id.mood_title, "How do you feel?")

                for (i in 0..4) {
                    val level = i + 1
                    val bmp = drawMoodButton(context, level, selected = false)
                    views.setImageViewBitmap(PROMPT_BTN_IDS[i], bmp)

                    val broadcastPi = PendingIntent.getBroadcast(
                        context,
                        200 + level, // unique request codes per level
                        Intent(MoodActionReceiver.ACTION_LOG_MOOD).apply {
                            setPackage(context.packageName)
                            putExtra("level", level)
                        },
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                    views.setOnClickPendingIntent(PROMPT_BTN_IDS[i], broadcastPi)
                }
            } else {
                // Logged panel.
                views.setViewVisibility(R.id.mood_panel_prompt, View.GONE)
                views.setViewVisibility(R.id.mood_panel_logged, View.VISIBLE)
                views.setTextViewText(R.id.mood_title, "Today's mood")

                val level = (json?.optInt("todayLevel", 3) ?: 3).coerceIn(1, 5)
                val loggedBmp = drawMoodButton(context, level, selected = true, sizeDp = 40)
                views.setImageViewBitmap(R.id.mood_logged_icon, loggedBmp)

                views.setTextViewText(R.id.mood_logged_label, MOOD_LABELS[level - 1])

                // Trend dots (up to 4 recent moods).
                val recentArr = json?.optJSONArray("recentLevels")
                for (i in 0..3) {
                    val dotLevel = if (recentArr != null && i < recentArr.length()) {
                        recentArr.getInt(i).coerceIn(1, 5)
                    } else 0 // 0 = no data → grey dot
                    val dotBmp = drawTrendDot(context, dotLevel)
                    views.setImageViewBitmap(TREND_IDS[i], dotBmp)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        // ── Bitmap helpers ───────────────────────────────────────────────────

        /**
         * Draws an emoji mood button (filled circle + emoji text).
         * [selected] = true → full opacity circle; false → 40% opacity (unselected state).
         */
        private fun drawMoodButton(
            context: Context,
            level: Int, // 1–5
            selected: Boolean,
            sizeDp: Int = 36,
        ): Bitmap {
            val px = (context.resources.displayMetrics.density * sizeDp).toInt().coerceAtLeast(36)
            val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val cx = px / 2f
            val r = cx * 0.9f

            // Background circle.
            val baseColor = MOOD_COLORS[level - 1]
            paint.style = Paint.Style.FILL
            paint.color = if (selected) baseColor
            else Color.argb(70, Color.red(baseColor), Color.green(baseColor), Color.blue(baseColor))
            canvas.drawCircle(cx, cx, r, paint)

            // Emoji text.
            val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                textSize = px * 0.48f
                textAlign = Paint.Align.CENTER
                typeface = Typeface.DEFAULT
            }
            val emoji = MOOD_EMOJIS[level - 1]
            val textY = cx - (textPaint.descent() + textPaint.ascent()) / 2f
            canvas.drawText(emoji, cx, textY, textPaint)

            return bmp
        }

        /**
         * Draws a small 10dp solid dot for the trend row.
         * [level] 0 → grey (no data); 1–5 → mood colour.
         */
        private fun drawTrendDot(context: Context, level: Int): Bitmap {
            val px = (context.resources.displayMetrics.density * 10).toInt().coerceAtLeast(10)
            val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.style = Paint.Style.FILL
            paint.color = if (level in 1..5) MOOD_COLORS[level - 1]
            else Color.argb(60, 150, 150, 150)
            canvas.drawCircle(px / 2f, px / 2f, px / 2f, paint)
            return bmp
        }
    }
}
