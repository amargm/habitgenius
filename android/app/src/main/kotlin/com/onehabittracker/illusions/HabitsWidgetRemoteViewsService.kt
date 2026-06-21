package com.onehabittracker.illusions

import android.content.Context
import android.content.Intent
import android.widget.RemoteViewsService

/**
 * Supplies the [HabitsWidgetRowFactory] to the ListView in the widget.
 */
class HabitsWidgetRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return HabitsWidgetRowFactory(applicationContext)
    }
}
