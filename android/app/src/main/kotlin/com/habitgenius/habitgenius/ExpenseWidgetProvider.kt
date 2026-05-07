package com.habitgenius

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import kotlin.math.abs

/**
 * Expense Balance home-screen widget (2×1).
 *
 * Read-only glance: primary account balance, today's spend, month total.
 * Tap anywhere → launch app.
 *
 * Data source: SharedPreferences key "flutter.hw_expenses"
 * Guests see a "Sign in to track finances" prompt.
 *
 * Play Store compliance:
 *  - Single launcher PendingIntent on the open button only
 *  - exported="true" only for the AppWidgetProvider receiver
 */
class ExpenseWidgetProvider : AppWidgetProvider() {

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
                ComponentName(context, ExpenseWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, ExpenseWidgetProvider::class.java).apply {
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
            val raw = prefs.getString("flutter.hw_expenses", null)
            val json = raw?.let { runCatching { JSONObject(it) }.getOrNull() }

            val views = RemoteViews(context.packageName, R.layout.widget_expenses)

            // The entire widget surface launches the app (single tap target).
            val launchPi = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                ?.let {
                    PendingIntent.getActivity(
                        context, 0, it,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                }
            if (launchPi != null) views.setOnClickPendingIntent(R.id.expense_open_app, launchPi)

            val tier = json?.optString("tier", "guest") ?: "guest"

            if (tier == "guest" || json == null) {
                views.setViewVisibility(R.id.expense_balance, View.GONE)
                views.setViewVisibility(R.id.expense_today, View.GONE)
                views.setViewVisibility(R.id.expense_month, View.GONE)
                views.setViewVisibility(R.id.expense_locked_text, View.VISIBLE)
                appWidgetManager.updateAppWidget(widgetId, views)
                return
            }

            views.setViewVisibility(R.id.expense_locked_text, View.GONE)
            views.setViewVisibility(R.id.expense_balance, View.VISIBLE)
            views.setViewVisibility(R.id.expense_today, View.VISIBLE)
            views.setViewVisibility(R.id.expense_month, View.VISIBLE)

            val symbol = json.optString("currencySymbol", "$")
            val accounts = json.optJSONArray("accounts")
            val todayExpense = json.optDouble("todayExpense", 0.0)
            val monthExpense = json.optDouble("monthExpense", 0.0)

            // Primary balance: first account.
            val balanceText = if (accounts != null && accounts.length() > 0) {
                val acc = accounts.getJSONObject(0)
                val bal = acc.optDouble("balance", 0.0)
                val name = acc.optString("name", "Account")
                "$name: $symbol${formatAmount(bal)}"
            } else {
                "No accounts"
            }
            views.setTextViewText(R.id.expense_balance, balanceText)
            views.setTextViewText(R.id.expense_today, "Today: -$symbol${formatAmount(todayExpense)}")
            views.setTextViewText(R.id.expense_month, "Month: -$symbol${formatAmount(monthExpense)}")

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        private fun formatAmount(amount: Double): String {
            val abs = abs(amount)
            return if (abs >= 10_000) {
                "%.0f".format(abs)
            } else {
                "%.2f".format(abs)
            }
        }
    }
}
