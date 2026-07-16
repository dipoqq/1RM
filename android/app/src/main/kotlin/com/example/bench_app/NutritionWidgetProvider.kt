package com.example.bench_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget for the current day's nutrition (КБЖУ): calories eaten
 * against the daily target, plus the protein / fats / carbs line.
 *
 * Reads the values Dart's WidgetService.updateNutrition wrote into the shared
 * home_widget SharedPreferences container. Every display value arrives as a
 * pre-formatted, pre-localised string; only the calorie bar percent crosses as
 * an int — the same convention as OneRMWidgetProvider, and for the same
 * reason (home_widget stores Dart doubles as raw long bits).
 */
class NutritionWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val title = widgetData.getString("widget_nutrition_title", "Nutrition · Today")
            ?: "Nutrition · Today"
        val kcal = widgetData.getString("widget_nutrition_kcal", "0 / 0 kcal")
            ?: "0 / 0 kcal"
        val macros = widgetData.getString("widget_nutrition_macros", "") ?: ""
        val percent = widgetData.getInt("widget_nutrition_percent", 0)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nutrition_widget).apply {
                setTextViewText(R.id.nutrition_title, title)
                setTextViewText(R.id.nutrition_kcal, kcal)
                setTextViewText(R.id.nutrition_percent, "$percent%")
                setTextViewText(R.id.nutrition_macros, macros)
                setProgressBar(R.id.nutrition_progress, 100, percent, false)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
