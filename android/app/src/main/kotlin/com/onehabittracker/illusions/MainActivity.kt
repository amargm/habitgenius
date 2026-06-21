package com.onehabittracker.illusions

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val WIDGET_CHANNEL = "com.onehabittracker/widget"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // Legacy single-widget update (habits only) — kept for safety.
                    "updateWidget" -> {
                        val data = call.argument<String>("data")
                        if (!data.isNullOrBlank()) {
                            writePrefs("flutter.hw_widget_habits", data)
                        }
                        HabitsWidgetProvider.triggerUpdate(applicationContext)
                        result.success(null)
                    }

                    // Pushes all four widget payloads in one call.
                    "pushAll" -> {
                        val habitsData   = call.argument<String>("habits")
                        val moodData     = call.argument<String>("mood")
                        val focusData    = call.argument<String>("focus")
                        val expensesData = call.argument<String>("expenses")

                        val prefs = applicationContext.getSharedPreferences(
                            "FlutterSharedPreferences", MODE_PRIVATE,
                        )
                        prefs.edit().apply {
                            if (!habitsData.isNullOrBlank())
                                putString("flutter.hw_widget_habits", habitsData)
                            if (!moodData.isNullOrBlank())
                                putString("flutter.hw_mood", moodData)
                            if (!focusData.isNullOrBlank()) {
                                putString("flutter.hw_focus_stats", focusData)
                                // Persist last category/mode so FocusTimerReceiver
                                // can use them when starting a session from the widget.
                                runCatching {
                                    val focusJson = org.json.JSONObject(focusData)
                                    focusJson.optString("lastCategory", "").takeIf { it.isNotEmpty() }
                                        ?.let { putString("flutter.hw_last_category", it) }
                                    focusJson.optString("lastMode", "").takeIf { it.isNotEmpty() }
                                        ?.let { putString("flutter.hw_last_mode", it) }
                                }
                            }
                            if (!expensesData.isNullOrBlank())
                                putString("flutter.hw_expenses", expensesData)
                            apply()
                        }

                        HabitsWidgetProvider.triggerUpdate(applicationContext)
                        MoodWidgetProvider.triggerUpdate(applicationContext)
                        FocusWidgetProvider.triggerUpdate(applicationContext)
                        ExpenseWidgetProvider.triggerUpdate(applicationContext)
                        StreakWidgetProvider.triggerUpdate(applicationContext)

                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun writePrefs(key: String, value: String) {
        applicationContext
            .getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit().putString(key, value).apply()
    }
}
