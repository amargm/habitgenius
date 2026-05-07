package com.habitgenius

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val WIDGET_CHANNEL = "com.habitgenius/widget"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        // The Flutter side may pass the new JSON via the "data" argument.
                        // Write it to SharedPreferences before triggering the redraw so
                        // the widget always reads the freshest snapshot.
                        val data = call.argument<String>("data")
                        if (!data.isNullOrBlank()) {
                            applicationContext
                                .getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                                .edit()
                                .putString("flutter.hw_widget_habits", data)
                                .apply()
                        }
                        HabitsWidgetProvider.triggerUpdate(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
