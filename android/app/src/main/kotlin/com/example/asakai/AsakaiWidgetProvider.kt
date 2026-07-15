package com.asakai.asakai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate

class AsakaiWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val isJapanese = context.resources.configuration.locales[0].language == "ja"
        val defaultTitle = if (isJapanese) "今日のタスク" else "Today’s Tasks"
        val defaultPrompt = if (isJapanese) "今日は何をする？" else "What are you planning today?"
        val title = widgetData.getString("asakai_widget_title", defaultTitle) ?: defaultTitle
        val prompt = widgetData.getString("asakai_widget_prompt", defaultPrompt) ?: defaultPrompt
        val savedDate = widgetData.getString("asakai_widget_date", "")
        val hasCurrentTasks = savedDate == LocalDate.now().toString()
        val lines = if (hasCurrentTasks) {
            widgetData.getString("asakai_widget_lines", "")
                ?.split("\n")
                .orEmpty()
        } else {
            emptyList()
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.asakai_widget).apply {
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_prompt, prompt)
                setViewVisibility(R.id.widget_prompt, if (lines.isEmpty()) android.view.View.VISIBLE else android.view.View.GONE)
                val lineViews = intArrayOf(
                    R.id.widget_line_1,
                    R.id.widget_line_2,
                    R.id.widget_line_3,
                    R.id.widget_line_4,
                    R.id.widget_line_5,
                    R.id.widget_line_6,
                )
                lineViews.forEachIndexed { index, id ->
                    val line = lines.getOrNull(index)
                    setViewVisibility(id, if (line == null) android.view.View.GONE else android.view.View.VISIBLE)
                    if (line != null) setTextViewText(id, line)
                }
                setOnClickPendingIntent(
                    R.id.widget_container,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
