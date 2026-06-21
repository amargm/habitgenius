package com.onehabittracker.illusions

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.min

/**
 * Produces one RemoteViews row per habit, showing:
 *  - Habit icon (emoji) and name
 *  - 7 day-cell bitmaps (Mon–Sun), colour-coded by habit's colorHex
 *  - A quick-log button that broadcasts [HabitsWidgetActionReceiver.ACTION_LOG_HABIT]
 */
class HabitsWidgetRowFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private data class HabitRow(
        val id: String,
        val name: String,
        val icon: String,
        val colorHex: String,
        val progressType: String,
        val targetValue: Int,
        val scheduledToday: Boolean,
        val todayCompleted: Boolean,
        val todayValue: Int,
        val weekStatus: List<DayStatus>,
    )

    private data class DayStatus(
        val scheduled: Boolean,
        val completed: Boolean,
        val value: Int,
        val progress: Double,
    )

    private var rows: List<HabitRow> = emptyList()

    // RemoteViewsFactory lifecycle ──────────────────────────────────────────

    override fun onCreate() = reload()

    override fun onDataSetChanged() {
        // Read the LATEST data from SharedPreferences instead of the stale
        // intent extra so refreshes after pushAll() always reflect new data.
        reload()
    }

    override fun onDestroy() {}

    override fun getCount(): Int = rows.size
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
    override fun getViewTypeCount(): Int = 1
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= rows.size) {
            return RemoteViews(context.packageName, R.layout.widget_habit_row_item)
        }
        val row = rows[position]
        val rv = RemoteViews(context.packageName, R.layout.widget_habit_row_item)

        rv.setTextViewText(R.id.habit_icon, row.icon)
        rv.setTextViewText(R.id.habit_name, row.name)

        // Day cells
        val dayCellIds = intArrayOf(
            R.id.day_0, R.id.day_1, R.id.day_2,
            R.id.day_3, R.id.day_4, R.id.day_5, R.id.day_6,
        )
        val accentColor = parseColor(row.colorHex)
        row.weekStatus.forEachIndexed { i, day ->
            if (i < dayCellIds.size) {
                val bmp = drawDayCell(
                    accentColor = accentColor,
                    scheduled = day.scheduled,
                    completed = day.completed,
                    progress = day.progress.toFloat(),
                )
                rv.setImageViewBitmap(dayCellIds[i], bmp)
            }
        }

        // Quick-log button: show checkmark if done, + icon if not
        val logBmp = drawLogButton(
            accentColor = accentColor,
            completed = row.todayCompleted,
            scheduledToday = row.scheduledToday,
        )
        rv.setImageViewBitmap(R.id.habit_log_btn, logBmp)

        // Fill-in intent so the template PendingIntent gets the right extras.
        val fillIn = Intent().apply {
            putExtra("habitId", row.id)
            putExtra("progressType", row.progressType)
            putExtra("targetValue", row.targetValue)
        }
        rv.setOnClickFillInIntent(R.id.habit_log_btn, fillIn)

        return rv
    }

    // ── Data loading ────────────────────────────────────────────────────────

    private fun reload() {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE,
        )
        val fresh = prefs.getString("flutter.hw_widget_habits", "") ?: ""
        rows = runCatching { parseRows(fresh) }.getOrElse { e ->
            android.util.Log.e("HabitsWidgetFactory", "parseRows failed — widget will show empty state", e)
            emptyList()
        }
    }

    private fun parseRows(json: String): List<HabitRow> {
        if (json.isBlank()) return emptyList()
        val root = JSONObject(json)
        val habitsArr: JSONArray = root.optJSONArray("habits") ?: return emptyList()
        return (0 until habitsArr.length()).map { i ->
            val h = habitsArr.getJSONObject(i)
            val weekArr = h.optJSONArray("weekStatus") ?: JSONArray()
            val weekStatus = (0 until weekArr.length()).map { j ->
                val d = weekArr.getJSONObject(j)
                DayStatus(
                    scheduled = d.optBoolean("scheduled"),
                    completed = d.optBoolean("completed"),
                    value = d.optInt("value"),
                    progress = d.optDouble("progress", 0.0),
                )
            }
            HabitRow(
                id = h.optString("id"),
                name = h.optString("name"),
                icon = h.optString("icon"),
                colorHex = h.optString("colorHex", "#6750A4"),
                progressType = h.optString("progressType", "checkbox"),
                targetValue = h.optInt("targetValue", 1),
                scheduledToday = h.optBoolean("scheduledToday"),
                todayCompleted = h.optBoolean("todayCompleted"),
                todayValue = h.optInt("todayValue"),
                weekStatus = weekStatus,
            )
        }
    }

    // ── Bitmap drawing ──────────────────────────────────────────────────────

    private val cellSizePx: Int
        get() = (context.resources.displayMetrics.density * 20).toInt().coerceAtLeast(20)

    /**
     * Draws a single 20×20 dp day-cell bitmap:
     * - Not scheduled → very faint grey dot
     * - Scheduled, not done, no progress → outlined circle (accent, low alpha)
     * - Partial progress (counter/timer) → arc fill proportional to [progress]
     * - Completed → filled circle with a tick
     */
    private fun drawDayCell(
        accentColor: Int,
        scheduled: Boolean,
        completed: Boolean,
        progress: Float,
    ): Bitmap {
        val size = cellSizePx
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val half = size / 2f
        val radius = half * 0.85f
        val rect = RectF(half - radius, half - radius, half + radius, half + radius)

        when {
            !scheduled -> {
                // Barely visible dot.
                paint.style = Paint.Style.FILL
                paint.color = Color.argb(40, 128, 128, 128)
                canvas.drawCircle(half, half, radius * 0.4f, paint)
            }
            completed -> {
                // Filled circle.
                paint.style = Paint.Style.FILL
                paint.color = accentColor
                canvas.drawCircle(half, half, radius, paint)
                // Tick mark.
                paint.style = Paint.Style.STROKE
                paint.color = Color.WHITE
                paint.strokeWidth = size * 0.12f
                paint.strokeCap = Paint.Cap.ROUND
                val tx = half - radius * 0.32f
                val ty = half + radius * 0.05f
                canvas.drawLine(tx - radius * 0.22f, ty, tx, ty + radius * 0.28f, paint)
                canvas.drawLine(tx, ty + radius * 0.28f, tx + radius * 0.42f, ty - radius * 0.32f, paint)
            }
            progress > 0f -> {
                // Partial arc.
                paint.style = Paint.Style.FILL
                paint.color = Color.argb(40, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor))
                canvas.drawCircle(half, half, radius, paint)
                paint.style = Paint.Style.STROKE
                paint.color = accentColor
                paint.strokeWidth = size * 0.14f
                canvas.drawArc(rect, -90f, 360f * progress.coerceIn(0f, 1f), false, paint)
            }
            else -> {
                // Outlined circle (scheduled, not started).
                paint.style = Paint.Style.STROKE
                paint.color = Color.argb(100, Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor))
                paint.strokeWidth = size * 0.1f
                canvas.drawCircle(half, half, radius, paint)
            }
        }
        return bmp
    }

    /**
     * Draws the quick-log button:
     * - Completed → filled accent circle with a tick
     * - Scheduled but not done → filled accent circle with a "+" sign
     * - Not scheduled today → grey dot (still tappable to force-log)
     */
    private fun drawLogButton(
        accentColor: Int,
        completed: Boolean,
        scheduledToday: Boolean,
    ): Bitmap {
        val size = (context.resources.displayMetrics.density * 24).toInt().coerceAtLeast(24)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val half = size / 2f
        val radius = half * 0.88f

        val bgColor = when {
            completed -> accentColor
            scheduledToday -> accentColor
            else -> Color.argb(80, 150, 150, 150)
        }
        paint.style = Paint.Style.FILL
        paint.color = bgColor
        canvas.drawCircle(half, half, radius, paint)

        paint.style = Paint.Style.STROKE
        paint.color = Color.WHITE
        paint.strokeWidth = size * 0.12f
        paint.strokeCap = Paint.Cap.ROUND

        if (completed) {
            // Tick
            val tx = half - radius * 0.28f
            val ty = half + radius * 0.05f
            canvas.drawLine(tx - radius * 0.18f, ty, tx, ty + radius * 0.26f, paint)
            canvas.drawLine(tx, ty + radius * 0.26f, tx + radius * 0.38f, ty - radius * 0.28f, paint)
        } else {
            // Plus
            canvas.drawLine(half, half - radius * 0.45f, half, half + radius * 0.45f, paint)
            canvas.drawLine(half - radius * 0.45f, half, half + radius * 0.45f, half, paint)
        }
        return bmp
    }

    private fun parseColor(hex: String): Int {
        return runCatching { Color.parseColor(hex) }.getOrElse { Color.parseColor("#6750A4") }
    }
}
