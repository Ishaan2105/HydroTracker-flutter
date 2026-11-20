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

        const val TIER_COMPACT = 1       // 2 buttons: Glass, 250
        const val TIER_ROW_3 = 2         // 3 buttons: Glass, 250, 500
        const val TIER_ROW_4 = 3         // 4 buttons: Glass, 250, 500, 750
        const val TIER_WIDE_5 = 4        // 5 buttons: Glass, 250, 500, 750, 1000
        const val TIER_VERTICAL_2ROW = 5 // Resized vertically: buttons below Glass & 250
        const val TIER_EXPANDED = 6      // Large expanded widget
        const val TIER_SQUARE = 7        // 2x2 square widget layout

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
            tier: Int = TIER_COMPACT
        ): RemoteViews {
            val layoutRes = when (tier) {
                TIER_EXPANDED -> R.layout.widget_hydro_layout_expanded
                TIER_VERTICAL_2ROW -> R.layout.widget_hydro_layout_vertical
                TIER_SQUARE -> R.layout.widget_hydro_layout_square
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

            // Button 2 (Priority #2): 250 ml Button (NO plus sign)
            val btn250Text = "250 ml"
            views.setTextViewText(R.id.widget_btn_250, btn250Text)
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

            // Button 3 (Priority #3): 500 ml (Tiers 2, 3, 4, 5, 6) (NO plus sign)
            if (tier in listOf(TIER_ROW_3, TIER_ROW_4, TIER_WIDE_5, TIER_VERTICAL_2ROW, TIER_EXPANDED)) {
                val btn500Text = if (tier == TIER_WIDE_5) "500" else "500 ml"
                views.setTextViewText(R.id.widget_btn_500, btn500Text)
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

            // Button 4 (Priority #4): 750 ml (Tiers 3, 4, 5, 6) (NO plus sign)
            if (tier in listOf(TIER_ROW_4, TIER_WIDE_5, TIER_VERTICAL_2ROW, TIER_EXPANDED)) {
                val btn750Text = if (tier == TIER_WIDE_5) "750" else "750 ml"
                views.setTextViewText(R.id.widget_btn_750, btn750Text)
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

            // Button 5 (Priority #5): 1000 ml (Tiers 4, 5, 6) (NO plus sign)
            if (tier in listOf(TIER_WIDE_5, TIER_VERTICAL_2ROW, TIER_EXPANDED)) {
                val btn1000Text = if (tier == TIER_WIDE_5) "1000" else "1000 ml"
                views.setTextViewText(R.id.widget_btn_1000, btn1000Text)
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
            return buildWidgetViews(context, intake, goal, tier = TIER_COMPACT)
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
                    val vCompact = buildWidgetViews(context, intakeMl, goalMl, tier = TIER_COMPACT)
                    val vSquare = buildWidgetViews(context, intakeMl, goalMl, tier = TIER_SQUARE)
                    val vVertical = buildWidgetViews(context, intakeMl, goalMl, tier = TIER_VERTICAL_2ROW)
                    val vExpanded = buildWidgetViews(context, intakeMl, goalMl, tier = TIER_EXPANDED)

                    val viewMapping = mapOf(
                        // 1-cell height variations (height 35dp - 69dp): Clean 2-button layout (Glass & 250 ml ONLY)
                        SizeF(100f, 35f) to vCompact,
                        SizeF(120f, 35f) to vCompact,
                        SizeF(155f, 35f) to vCompact,  // 3x1 size: Glass & 250 ml ONLY
                        SizeF(215f, 35f) to vCompact,  // 4x1 size: Glass & 250 ml ONLY
                        SizeF(270f, 35f) to vCompact,  // 5x1 size: Glass & 250 ml ONLY

                        // Square / 2x2 size (narrow width < 155dp, taller height >= 70dp)
                        SizeF(100f, 70f) to vSquare,   // 2x2 square layout

                        // Vertical expansions (width >= 155dp, taller height >= 70dp: buttons added below)
                        SizeF(155f, 70f) to vVertical, // 3x2, 4x2 vertical 2-row layout
                        SizeF(240f, 115f) to vExpanded // 4x3+ large expanded widget
                    )
                    val responsiveViews = RemoteViews(viewMapping)
                    appWidgetManager.updateAppWidget(appWidgetId, responsiveViews)
                } else {
                    val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                    val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 180
                    val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 60

                    val tier = when {
                        minHeight >= 115 && minWidth >= 240 -> TIER_EXPANDED
                        minHeight >= 70 && minWidth >= 155 -> TIER_VERTICAL_2ROW
                        minHeight >= 70 && minWidth < 155 -> TIER_SQUARE
                        else -> TIER_COMPACT  // All 1-row horizontal widgets: Glass & 250 ml ONLY
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
