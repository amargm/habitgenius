package com.habitgenius

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * AppWidgetProvider for the HabitGenius home-screen widget.
 *
 * Reads the JSON snapshot stored in SharedPreferences by WidgetSyncService
 * (Flutter writes with the "flutter." prefix, so we read the Flutter-shared-
 * preferences file with the raw key "hw_widget_habits").
 *
 * The ONLY PendingIntent that launches the app is the "Open" button. All
 * quick-log actions use Broadcast PendingIntents.
 */
class HabitsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { widgetId ->
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        /** Called from MainActivity's platform-channel handler. */
        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, HabitsWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, HabitsWidgetProvider::class.java).apply {
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
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
            )
            val raw = prefs.getString("flutter.hw_widget_habits", null)

            val views = RemoteViews(context.packageName, R.layout.widget_habits)

            // ── Open-app button (only launcher PendingIntent) ─────────────
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            if (launchIntent != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_open_app, pi)
            }

            if (raw.isNullOrBlank()) {
                // No data yet — show empty state.
                views.setViewVisibility(
                    R.id.widget_habit_list,
                    android.view.View.GONE,
                )
                views.setViewVisibility(
                    R.id.widget_empty_text,
                    android.view.View.VISIBLE,
                )
                appWidgetManager.updateAppWidget(widgetId, views)
                return
            }

            val json = runCatching { JSONObject(raw) }.getOrNull()
            val habits = json?.optJSONArray("habits")

            if (habits == null || habits.length() == 0) {
                views.setViewVisibility(
                    R.id.widget_habit_list,
                    android.view.View.GONE,
                )
                views.setViewVisibility(
                    R.id.widget_empty_text,
                    android.view.View.VISIBLE,
                )
                appWidgetManager.updateAppWidget(widgetId, views)
                return
            }

            // ── ListView with RemoteViewsService adapter ──────────────────
            views.setViewVisibility(R.id.widget_habit_list, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty_text, android.view.View.GONE)

            val serviceIntent = Intent(context, HabitsWidgetRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                // Pass the raw JSON through the intent so the factory can read it.
                putExtra("widget_data", raw)
            }
            views.setRemoteAdapter(R.id.widget_habit_list, serviceIntent)
            views.setEmptyView(R.id.widget_habit_list, R.id.widget_empty_text)

            // Template PendingIntent for list-item click actions.
            // HabitsWidgetRowFactory sets the fill-in intent per row.
            val actionIntent = Intent(HabitsWidgetActionReceiver.ACTION_LOG_HABIT)
            val templatePi = PendingIntent.getBroadcast(
                context, widgetId, actionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            views.setPendingIntentTemplate(R.id.widget_habit_list, templatePi)

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_habit_list)
        }
    }
}
