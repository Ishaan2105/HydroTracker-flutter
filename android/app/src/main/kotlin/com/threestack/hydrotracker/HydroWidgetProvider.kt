package com.threestack.hydrotracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class HydroWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "HydroWidget"
        const val ACTION_ADD_WATER = "com.threestack.hydrotracker.ACTION_ADD_WATER"
        const val EXTRA_AMOUNT = "extra_amount"
        const val EXTRA_TRIGGER_ACTION = "extra_trigger_action"
        const val ACTION_CREATE_GLASS = "create_glass"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_INTAKE = "flutter.today_intake_ml"
        private const val KEY_GOAL = "flutter.daily_goal_ml"
        private const val KEY_PENDING_LOGS = "flutter.pending_widget_logs"
        private const val KEY_WIDGET_DATE = "flutter.widget_last_active_date"
        private const val KEY_HAS_CONFIGURED_GLASS = "flutter.has_configured_glass"
        private const val KEY_CUSTOM_GLASS_ML = "flutter.custom_glass_ml"

        fun getSafeInt(prefs: SharedPreferences, key: String, defaultVal: Int): Int {
            return try {
                prefs.getLong(key, defaultVal.toLong()).toInt()
            } catch (_: ClassCastException) {
                try {
                    prefs.getInt(key, defaultVal)
                } catch (_: Exception) {
                    defaultVal
                }
            }
        }

        fun getSafeBoolean(prefs: SharedPreferences, key: String, defaultVal: Boolean): Boolean {
            return try {
                prefs.getBoolean(key, defaultVal)
            } catch (_: Exception) {
                defaultVal
            }
        }

        fun checkMidnightRollover(prefs: SharedPreferences): Int {
            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val lastDate = prefs.getString(KEY_WIDGET_DATE, null)
            if (lastDate != null && lastDate != todayStr) {
                // Day rolled over while app was inactive — reset today's intake to 0
                prefs.edit()
                    .putLong(KEY_INTAKE, 0L)
                    .putString(KEY_PENDING_LOGS, "")
                    .putString(KEY_WIDGET_DATE, todayStr)
                    .apply()
                return 0
            } else if (lastDate == null) {
                prefs.edit().putString(KEY_WIDGET_DATE, todayStr).apply()
            }
            return getSafeInt(prefs, KEY_INTAKE, 0)
        }

        fun buildWidgetViews(
            context: Context,
            intakeMl: Int,
            goalMl: Int,
            tier: Int = 1
        ): RemoteViews {
            val layoutRes = when (tier) {
                4 -> R.layout.widget_hydro_layout_expanded
                3 -> R.layout.widget_hydro_layout_tier3
                2 -> R.layout.widget_hydro_layout_tier2
                else -> R.layout.widget_hydro_layout
            }
            val views = RemoteViews(context.packageName, layoutRes)

            val safeGoal = if (goalMl > 0) goalMl else 2500
            val progressPct = ((intakeMl.toFloat() / safeGoal.toFloat()) * 100).toInt().coerceIn(0, 100)

            views.setProgressBar(R.id.widget_progress_bar, 100, progressPct, false)
            views.setTextViewText(R.id.widget_text_intake, "$intakeMl / $safeGoal ml")
            views.setTextViewText(R.id.widget_text_percent, "$progressPct%")

            // Body / Circle tap opens app
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingAppIntent = PendingIntent.getActivity(
                context,
                100,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingAppIntent)
            views.setOnClickPendingIntent(R.id.widget_circle_container, pendingAppIntent)

            // Glass configuration status
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val hasConfiguredGlass = getSafeBoolean(prefs, KEY_HAS_CONFIGURED_GLASS, false)
            val customGlassMl = getSafeInt(prefs, KEY_CUSTOM_GLASS_ML, 200).coerceIn(50, 1000)

            // Button 1 (Priority #1): Glass Button
            views.setTextViewText(R.id.widget_btn_glass, "Glass")
            if (hasConfiguredGlass) {
                val addGlassIntent = Intent(context, HydroWidgetProvider::class.java).apply {
                    action = ACTION_ADD_WATER
                    putExtra(EXTRA_AMOUNT, customGlassMl)
                }
                val pendingAddGlass = PendingIntent.getBroadcast(
                    context,
                    104,
                    addGlassIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_glass, pendingAddGlass)
            } else {
                val createGlassIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra(EXTRA_TRIGGER_ACTION, ACTION_CREATE_GLASS)
                }
                val pendingCreateGlass = PendingIntent.getActivity(
                    context,
                    103,
                    createGlassIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_glass, pendingCreateGlass)
            }

            // Button 2 (Priority #2): +250 ml Button
            views.setTextViewText(R.id.widget_btn_250, "+250 ml")
            val add250Intent = Intent(context, HydroWidgetProvider::class.java).apply {
                action = ACTION_ADD_WATER
                putExtra(EXTRA_AMOUNT, 250)
            }
            val pendingAdd250 = PendingIntent.getBroadcast(
                context,
                101,
                add250Intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_250, pendingAdd250)

            // Button 3 (Priority #3): +500 ml (Tiers 2, 3, 4)
            if (tier >= 2) {
                views.setTextViewText(R.id.widget_btn_500, "+500 ml")
                val add500Intent = Intent(context, HydroWidgetProvider::class.java).apply {
                    action = ACTION_ADD_WATER
                    putExtra(EXTRA_AMOUNT, 500)
                }
                val pendingAdd500 = PendingIntent.getBroadcast(
                    context,
                    105,
                    add500Intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_500, pendingAdd500)
            }

            // Button 4 (Priority #4): +750 ml (Tiers 3, 4)
            if (tier >= 3) {
                views.setTextViewText(R.id.widget_btn_750, "+750 ml")
                val add750Intent = Intent(context, HydroWidgetProvider::class.java).apply {
                    action = ACTION_ADD_WATER
                    putExtra(EXTRA_AMOUNT, 750)
                }
                val pendingAdd750 = PendingIntent.getBroadcast(
                    context,
                    106,
                    add750Intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_750, pendingAdd750)
            }

            // Button 5 (Priority #5): +1000 ml (Tier 4)
            if (tier >= 4) {
                views.setTextViewText(R.id.widget_btn_1000, "+1000 ml")
                val add1000Intent = Intent(context, HydroWidgetProvider::class.java).apply {
                    action = ACTION_ADD_WATER
                    putExtra(EXTRA_AMOUNT, 1000)
                }
                val pendingAdd1000 = PendingIntent.getBroadcast(
                    context,
                    107,
                    add1000Intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_1000, pendingAdd1000)
            }

            return views
        }

        fun buildPreviewViews(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val intake = checkMidnightRollover(prefs)
            val goal = getSafeInt(prefs, KEY_GOAL, 2500)
            return buildWidgetViews(context, intake, goal, tier = 1)
        }

        fun updateAllWidgets(context: Context, intakeMl: Int, goalMl: Int) {
            try {
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putLong(KEY_INTAKE, intakeMl.toLong())
                    .putLong(KEY_GOAL, goalMl.toLong())
                    .putString(KEY_WIDGET_DATE, todayStr)
                    .apply()

                val appWidgetManager = AppWidgetManager.getInstance(context)
                val thisWidget = ComponentName(context, HydroWidgetProvider::class.java)
                val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                for (widgetId in allWidgetIds) {
                    updateWidget(context, appWidgetManager, widgetId, intakeMl, goalMl)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error updating all widgets", e)
            }
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            intakeMl: Int,
            goalMl: Int
        ) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val tier1 = buildWidgetViews(context, intakeMl, goalMl, tier = 1)
                    val tier2 = buildWidgetViews(context, intakeMl, goalMl, tier = 2)
                    val tier3 = buildWidgetViews(context, intakeMl, goalMl, tier = 3)
                    val tier4 = buildWidgetViews(context, intakeMl, goalMl, tier = 4)
                    val viewMapping = mapOf(
                        SizeF(120f, 40f) to tier1,
                        SizeF(220f, 85f) to tier2,
                        SizeF(260f, 130f) to tier3,
                        SizeF(280f, 180f) to tier4
                    )
                    val responsiveViews = RemoteViews(viewMapping)
                    appWidgetManager.updateAppWidget(appWidgetId, responsiveViews)
                } else {
                    val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                    val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 180
                    val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 60
                    val tier = when {
                        minWidth >= 280 && minHeight >= 180 -> 4
                        minWidth >= 260 && minHeight >= 130 -> 3
                        minWidth >= 220 && minHeight >= 85 -> 2
                        else -> 1
                    }
                    val views = buildWidgetViews(context, intakeMl, goalMl, tier)
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error updating single widget $appWidgetId", e)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val intake = checkMidnightRollover(prefs)
            val goal = getSafeInt(prefs, KEY_GOAL, 2500)

            for (widgetId in appWidgetIds) {
                updateWidget(context, appWidgetManager, widgetId, intake, goal)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onUpdate", e)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val intake = checkMidnightRollover(prefs)
            val goal = getSafeInt(prefs, KEY_GOAL, 2500)
            updateWidget(context, appWidgetManager, appWidgetId, intake, goal)
        } catch (e: Exception) {
            Log.e(TAG, "Error in onAppWidgetOptionsChanged", e)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_ADD_WATER) {
            try {
                val amount = intent.getIntExtra(EXTRA_AMOUNT, 250)
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val currentIntake = checkMidnightRollover(prefs)
                val goal = getSafeInt(prefs, KEY_GOAL, 2500)
                val newIntake = currentIntake + amount
                val nowMillis = System.currentTimeMillis()
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

                // Append to pending queue
                val existingPending = prefs.getString(KEY_PENDING_LOGS, "") ?: ""
                val newEntry = "$amount|$nowMillis"
                val updatedPending = if (existingPending.isEmpty()) newEntry else "$existingPending;$newEntry"

                prefs.edit()
                    .putLong(KEY_INTAKE, newIntake.toLong())
                    .putString(KEY_PENDING_LOGS, updatedPending)
                    .putString(KEY_WIDGET_DATE, todayStr)
                    .apply()

                // Immediate visual update to widget
                updateAllWidgets(context, newIntake, goal)
            } catch (e: Exception) {
                Log.e(TAG, "Error in onReceive ACTION_ADD_WATER", e)
            }
        }
    }
}
