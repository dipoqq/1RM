package com.example.bench_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget for the active lift's estimated 1RM.
 *
 * Reads the values Dart's WidgetService wrote into the shared home_widget
 * SharedPreferences container. The kg values arrive as strings and the progress
 * as an int — see WidgetService for why (Dart doubles are stored as raw long
 * bits by home_widget, which is awkward to read back here).
 */
class OneRMWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // The lift picked in Settings ('benchPress' | 'squat' | 'deadlift'),
        // mirrored to this container so the native side can resolve a title
        // even before Dart pushes the display values for it.
        val selected = widgetData.getString("widget_selected_exercise", null)
        val fallbackName = when (selected) {
            "squat" -> "Squat"
            "deadlift" -> "Deadlift"
            else -> "Bench Press"
        }
        val exercise = widgetData.getString("widget_exercise_name", fallbackName)
            ?: fallbackName
        val current = widgetData.getString("widget_current_1rm", "0") ?: "0"
        val goal = widgetData.getString("widget_goal_1rm", "0") ?: "0"
        val percent = widgetData.getInt("widget_progress_percent", 0)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.one_r_m_widget).apply {
                setTextViewText(R.id.widget_title, "1RM · $exercise")
                setTextViewText(R.id.widget_value, "$current kg / $goal kg")
                setTextViewText(R.id.widget_percent, "$percent%")
                setProgressBar(R.id.widget_progress, 100, percent, false)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
