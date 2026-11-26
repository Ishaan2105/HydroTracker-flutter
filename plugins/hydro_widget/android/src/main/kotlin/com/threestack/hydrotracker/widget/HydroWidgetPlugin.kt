package com.threestack.hydrotracker.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class HydroWidgetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null

    companion object {
        const val CHANNEL_NAME = "hydro_flutter/widget"
        const val ACTION_UPDATE_WIDGET = "com.threestack.hydrotracker.ACTION_UPDATE_WIDGET"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateWidget", "updateWidgetData" -> {
                val ctx = context
                if (ctx != null) {
                    val intake = call.argument<Int>("todayIntakeMl")
                        ?: call.argument<Int>("todayIntake")
                        ?: 0
                    val goal = call.argument<Int>("dailyGoalMl")
                        ?: call.argument<Int>("dailyGoal")
                        ?: 2500
                    val customGlass = call.argument<Int>("customGlassMl")
                    val hasConfiguredGlass = call.argument<Boolean>("hasConfiguredGlass")

                    val intent = Intent(ACTION_UPDATE_WIDGET).apply {
                        component = android.content.ComponentName(ctx, "com.threestack.hydrotracker.HydroWidgetProvider")
                        putExtra("todayIntake", intake)
                        putExtra("dailyGoal", goal)
                        if (customGlass != null) putExtra("customGlass", customGlass)
                        if (hasConfiguredGlass != null) {
                            putExtra("hasConfiguredGlass", hasConfiguredGlass)
                            putExtra("hasGlass", hasConfiguredGlass)
                        }
                    }
                    ctx.sendBroadcast(intent)
                    result.success(true)
                } else {
                    result.error("NO_CONTEXT", "Application context is null", null)
                }
            }
            "isPinSupported" -> {
                val act = activity ?: context
                if (act != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val appWidgetManager = AppWidgetManager.getInstance(act)
                    result.success(appWidgetManager.isRequestPinAppWidgetSupported)
                } else {
                    result.success(false)
                }
            }
            "getInitialAction" -> {
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
