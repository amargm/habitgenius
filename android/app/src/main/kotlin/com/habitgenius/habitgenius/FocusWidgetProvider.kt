package com.habitgenius

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
import android.graphics.RectF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import kotlin.math.min

/**
 * Focus Timer home-screen widget (2×2).
 *
 * Displays a circular progress ring built from a Canvas Bitmap (updated on
 * every 60-second tick) plus ▶/⏸ and ↺ action buttons.
 *
 * Timer runtime state lives in SharedPreferences key "flutter.hw_focus"
 * (owned by [FocusTimerReceiver]).  Today's cumulative stats come from
 * "flutter.hw_focus_stats" (written by Flutter via the platform channel).
 *
 * Play Store compliance:
 *  - PendingIntent.FLAG_IMMUTABLE on all static intents
 *  - exported="true" only for the AppWidgetProvider receiver
 *  - AlarmManager.canScheduleExactAlarms() checked before setExact() on API 31+
 */
class FocusWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { id -> updateWidget(context, appWidgetManager, id) }
    }

    companion object {

        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, FocusWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, FocusWidgetProvider::class.java).apply {
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
            val timerRaw = prefs.getString("flutter.hw_focus", null)
            val statsRaw = prefs.getString("flutter.hw_focus_stats", null)

            val timer = timerRaw?.let { runCatching { JSONObject(it) }.getOrNull() }
            val stats = statsRaw?.let { runCatching { JSONObject(it) }.getOrNull() }

            val state = timer?.optString("state", "idle") ?: "idle"
            val targetSeconds = timer?.optInt("targetSeconds", 1500) ?: 1500
            val startedAt = timer?.optLong("startedAt", 0L) ?: 0L
            val pausedElapsed = timer?.optLong("pausedElapsed", 0L) ?: 0L
            val category = timer?.optString("category", "Deep Work") ?: "Deep Work"
            val mode = timer?.optString("mode", "Pomodoro") ?: "Pomodoro"
            val todaySeconds = stats?.optInt("todayFocusSeconds", 0) ?: 0

            // Calculate remaining seconds.
            val elapsedSeconds: Long = when (state) {
                "running" -> {
                    if (startedAt > 0) {
                        pausedElapsed + (System.currentTimeMillis() - startedAt) / 1000L
                    } else 0L
                }
                "paused" -> pausedElapsed
                "done" -> targetSeconds.toLong()
                else -> 0L
            }
            val remainingSeconds =
                (targetSeconds - elapsedSeconds).coerceIn(0L, targetSeconds.toLong())
            val progress = if (targetSeconds > 0) {
                (elapsedSeconds.toFloat() / targetSeconds).coerceIn(0f, 1f)
            } else 0f

            val views = RemoteViews(context.packageName, R.layout.widget_focus)

            // Open-app button (only launcher PendingIntent).
            val launchPi = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.let { it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); it }
                ?.let {
                    PendingIntent.getActivity(
                        context, 0, it,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                }
            if (launchPi != null) views.setOnClickPendingIntent(R.id.focus_open_app, launchPi)

            // Draw ring bitmap.
            val ringBmp = drawRing(context, progress, state)
            views.setImageViewBitmap(R.id.focus_ring, ringBmp)

            // Time text.
            val timeStr = formatSeconds(remainingSeconds)
            views.setTextViewText(R.id.focus_time, if (state == "done") "Done!" else timeStr)

            // Status label.
            val statusLabel = when (state) {
                "running" -> "$mode · $category"
                "paused"  -> "Paused · $category"
                "done"    -> "Session complete"
                else      -> mode
            }
            views.setTextViewText(R.id.focus_status_label, statusLabel)

            // Today label.
            val todayMin = todaySeconds / 60
            views.setTextViewText(R.id.focus_today_label, "Today: $todayMin min")

            // Primary action button and reset.
            val primaryAction = when (state) {
                "running" -> FocusTimerReceiver.ACTION_FOCUS_PAUSE
                "paused"  -> FocusTimerReceiver.ACTION_FOCUS_RESUME
                "done"    -> FocusTimerReceiver.ACTION_FOCUS_RESET
                else      -> FocusTimerReceiver.ACTION_FOCUS_START
            }
            val primaryPi = broadcastPi(context, primaryAction, 1)
            views.setOnClickPendingIntent(R.id.focus_btn_primary, primaryPi)

            val primaryIcon = when (state) {
                "running" -> android.R.drawable.ic_media_pause
                else      -> android.R.drawable.ic_media_play
            }
            views.setImageViewResource(R.id.focus_btn_primary, primaryIcon)

            // Reset button — hidden when idle.
            if (state == "idle") {
                views.setViewVisibility(R.id.focus_btn_reset, View.INVISIBLE)
            } else {
                views.setViewVisibility(R.id.focus_btn_reset, View.VISIBLE)
                val resetPi = broadcastPi(context, FocusTimerReceiver.ACTION_FOCUS_RESET, 2)
                views.setOnClickPendingIntent(R.id.focus_btn_reset, resetPi)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        // ── Broadcast PendingIntent helper ───────────────────────────────────

        private fun broadcastPi(context: Context, action: String, reqCode: Int): PendingIntent {
            val intent = Intent(action).apply {
                setPackage(context.packageName) // explicit for security
            }
            return PendingIntent.getBroadcast(
                context, reqCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        // ── Ring bitmap ──────────────────────────────────────────────────────

        private fun drawRing(context: Context, progress: Float, state: String): Bitmap {
            // Scale bitmap with screen density so the ring stays sharp on all displays.
            val density = context.resources.displayMetrics.density
            val size = (120 * density).toInt().coerceAtLeast(200)
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val cx = size / 2f
            val strokeW = size * 0.1f
            val r = cx - strokeW

            // Track (background ring).
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = strokeW
            paint.color = Color.argb(50, 150, 150, 150)
            canvas.drawCircle(cx, cx, r, paint)

            // Progress arc.
            val arcColor = when (state) {
                "running" -> Color.parseColor("#6C5CE7") // accent purple
                "paused"  -> Color.parseColor("#FDAA6E") // amber
                "done"    -> Color.parseColor("#00B894") // green
                else      -> Color.parseColor("#6C5CE7")
            }
            paint.color = arcColor
            paint.strokeCap = Paint.Cap.ROUND
            val rect = RectF(cx - r, cx - r, cx + r, cx + r)
            canvas.drawArc(rect, -90f, 360f * progress.coerceIn(0f, 1f), false, paint)

            return bmp
        }

        // ── Time formatting ──────────────────────────────────────────────────

        private fun formatSeconds(seconds: Long): String {
            val m = seconds / 60
            val s = seconds % 60
            return "%02d:%02d".format(m, s)
        }
    }
}
