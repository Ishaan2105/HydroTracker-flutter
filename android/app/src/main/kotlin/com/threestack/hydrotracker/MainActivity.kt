package com.threestack.hydrotracker

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "hydro_flutter/battery"
        private const val WIDGET_CHANNEL = "hydro_flutter/widget"
    }

    private var pendingWidgetAction: String? = null
    private var widgetMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntentAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntentAction(intent)
    }

    private fun handleIntentAction(intent: Intent?) {
        val action = intent?.getStringExtra(HydroWidgetProvider.EXTRA_TRIGGER_ACTION)
        if (action != null) {
            pendingWidgetAction = action
            widgetMethodChannel?.invokeMethod("onWidgetAction", action)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Android Home & Lock Screen Widget Channel
        val widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        widgetMethodChannel = widgetChannel

        widgetChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAction" -> {
                    val action = pendingWidgetAction
                    pendingWidgetAction = null
                    result.success(action)
                }
                "isPinSupported" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        result.success(appWidgetManager.isRequestPinAppWidgetSupported)
                    } else {
                        result.success(false)
                    }
                }
                "requestPinWidget" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        if (appWidgetManager.isRequestPinAppWidgetSupported) {
                            val myProvider = ComponentName(this, HydroWidgetProvider::class.java)
                            val previewViews = HydroWidgetProvider.buildPreviewViews(this)
                            val extras = Bundle().apply {
                                putParcelable(AppWidgetManager.EXTRA_APPWIDGET_PREVIEW, previewViews)
                            }
                            appWidgetManager.requestPinAppWidget(myProvider, extras, null)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "updateWidget", "updateWidgetData" -> {
                    val intake = call.argument<Int>("todayIntakeMl")
                        ?: call.argument<Int>("todayIntake")
                        ?: 0
                    val goal = call.argument<Int>("dailyGoalMl")
                        ?: call.argument<Int>("dailyGoal")
                        ?: 2500
                    val customGlass = call.argument<Int>("customGlassMl")
                    val hasConfiguredGlass = call.argument<Boolean>("hasConfiguredGlass")
                    HydroWidgetProvider.updateAllWidgets(this, intake, goal, customGlass, hasConfiguredGlass)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Returns true if this app is already exempt from battery optimizations.
                "checkBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true) // Pre-M devices don't have this restriction
                    }
                }

                // Opens the system dialog asking the user to grant battery optimization exemption.
                // On Samsung One UI this opens "Unrestricted" battery mode for the app.
                "requestBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(
                                android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            // Fallback: open general battery optimization settings
                            try {
                                val fallback = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                startActivity(fallback)
                                result.success(false)
                            } catch (e2: Exception) {
                                result.error("UNAVAILABLE", "Battery optimization settings unavailable", null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }

                // Opens Samsung Device Care battery page to guide the user to
                // "Background usage limits → Never sleeping apps" and disable App Sleep.
                "openSamsungDeviceCare" -> {
                    var opened = false
                    // Try Samsung Device Care directly
                    val samsungIntents = listOf(
                        "com.samsung.android.lool/.DeviceCareMainActivity",
                        "com.samsung.android.sm_cn/.DeviceCareMainActivity",
                        "com.samsung.android.lool/.ui.main.DeviceCareActivity",
                    )
                    for (componentStr in samsungIntents) {
                        try {
                            val parts = componentStr.split("/")
                            val intent = Intent().apply {
                                setClassName(parts[0], parts[0] + parts[1])
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            opened = true
                            break
                        } catch (_: Exception) {}
                    }
                    if (!opened) {
                        // Fallback: open this app's system detail page
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            opened = true
                        } catch (_: Exception) {}
                    }
                    result.success(opened)
                }

                "openNotificationSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                        } else {
                            Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
