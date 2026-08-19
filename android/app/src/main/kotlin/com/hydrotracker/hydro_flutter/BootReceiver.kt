package com.hydrotracker.hydro_flutter

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar
import java.util.Locale

/**
 * Native boot receiver — fully independent of Flutter engine.
 *
 * On BOOT_COMPLETED / LOCKED_BOOT_COMPLETED it:
 *  1. Reads saved alarm times from Flutter's SharedPreferences (flutter.* keys)
 *  2. Computes next occurrence for each active reminder
 *  3. Schedules via AlarmManager.setExactAndAllowWhileIdle
 *  4. When those alarms fire, AlarmNotificationReceiver shows the notification
 *
 * This runs in parallel with flutter_local_notifications' ScheduledNotificationBootReceiver.
 * If either one succeeds the alarm fires — double redundancy at the OS level.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID     = "hydro_tracker_reminders"
        const val CHANNEL_NAME   = "Hydration Reminders"
        const val EXTRA_NOTIF_ID = "hydro_notif_id"
        const val EXTRA_TITLE    = "hydro_notif_title"
        const val EXTRA_BODY     = "hydro_notif_body"

        /** ID range for native boot-scheduled alarms (avoids Flutter's 100–599 range). */
        private const val BOOT_ALARM_ID_START = 700
        private const val BOOT_POST_MEAL_ID_START = 750
    }

    override fun onReceive(context: Context, intent: Intent) {
        val validActions = setOf(
            "android.intent.action.BOOT_COMPLETED",
            "android.intent.action.LOCKED_BOOT_COMPLETED",
            "android.intent.action.MY_PACKAGE_REPLACED",
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
        )
        if (intent.action !in validActions) return

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Respect the user's notification toggle (stored by Flutter as "flutter.notif_enabled")
            val notifEnabled = prefs.getBoolean("flutter.notif_enabled", true)
            if (!notifEnabled) return

            createNotificationChannel(context)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // 1. Restore regular hydration reminder times
            val allTimes = prefs.getStringSet("flutter.reminder_times", null)
            val disabledTimes = prefs.getStringSet("flutter.disabled_reminder_times", emptySet()) ?: emptySet()
            if (allTimes != null) {
                val activeTimes = allTimes.filter { it !in disabledTimes }
                var notifId = BOOT_ALARM_ID_START
                for (timeStr in activeTimes) {
                    val nextMillis = calculateNextOccurrenceMillis(timeStr) ?: continue
                    scheduleAlarm(
                        context,
                        alarmManager,
                        notifId,
                        nextMillis,
                        "\uD83D\uDCA7 Time to Hydrate!",
                        "Stay on top of your goal with a fresh glass of water.",
                    )
                    notifId++
                }
            }

            // 2. Restore post-meal reminders (30m after meals)
            val postMealEnabled = prefs.getBoolean("flutter.post_meal_notif", true)
            if (postMealEnabled) {
                val mealList = listOf(
                    Triple("flutter.meal_bfast", "08:30 AM", "Breakfast"),
                    Triple("flutter.meal_lunch", "01:00 PM", "Lunch"),
                    Triple("flutter.meal_dinner", "08:00 PM", "Dinner"),
                )

                for ((index, item) in mealList.withIndex()) {
                    val (key, defaultTime, mealName) = item
                    val mealTimeStr = prefs.getString(key, defaultTime) ?: defaultTime
                    val postMealMillis = calculatePostMealOccurrenceMillis(mealTimeStr) ?: continue
                    scheduleAlarm(
                        context,
                        alarmManager,
                        BOOT_POST_MEAL_ID_START + index,
                        postMealMillis,
                        "\uD83C\uDF7D\uFE0F Post-$mealName Hydration \uD83D\uDCA7",
                        "It’s been 30 minutes since $mealName. Drink a glass of water for optimal digestion!",
                    )
                }
            }
        } catch (e: Exception) {
            // Silent fail — flutter_local_notifications receiver is primary backup
        }
    }

    // -------------------------------------------------------------------------

    private fun scheduleAlarm(
        context: Context,
        alarmManager: AlarmManager,
        notifId: Int,
        triggerAtMillis: Long,
        title: String = "\uD83D\uDCA7 Time to Hydrate!",
        body: String = "Stay on top of your goal with a fresh glass of water.",
    ) {
        val notifIntent = Intent(context, AlarmNotificationReceiver::class.java).apply {
            putExtra(EXTRA_NOTIF_ID, notifId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            notifId,
            notifIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }
    }

    /**
     * Parses a 12-hour ("08:00 AM") or 24-hour ("08:00") time string and
     * returns the next future epoch-millisecond that matches it.
     * Rolls to tomorrow if the time has already passed today.
     */
    private fun calculateNextOccurrenceMillis(timeStr: String): Long? {
        return try {
            val clean = timeStr.trim().uppercase(Locale.ROOT)
            val hour: Int
            val minute: Int

            if (clean.contains("AM") || clean.contains("PM")) {
                val isPm = clean.contains("PM")
                val timePart = clean.replace("AM", "").replace("PM", "").trim()
                val parts = timePart.split(":")
                if (parts.size < 2) return null
                var h = parts[0].trim().toInt()
                val m = parts[1].trim().toInt()
                if (isPm && h != 12) h += 12
                if (!isPm && h == 12) h = 0
                hour = h; minute = m
            } else {
                val parts = clean.split(":")
                if (parts.size < 2) return null
                hour = parts[0].trim().toInt()
                minute = parts[1].trim().toInt()
            }

            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            // If the time already passed today, schedule for tomorrow
            if (cal.timeInMillis <= System.currentTimeMillis()) {
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            cal.timeInMillis
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Calculates the next occurrence for a post-meal reminder (meal time + 30 minutes).
     */
    private fun calculatePostMealOccurrenceMillis(mealTimeStr: String): Long? {
        return try {
            val clean = mealTimeStr.trim().uppercase(Locale.ROOT)
            val hour: Int
            val minute: Int

            if (clean.contains("AM") || clean.contains("PM")) {
                val isPm = clean.contains("PM")
                val timePart = clean.replace("AM", "").replace("PM", "").trim()
                val parts = timePart.split(":")
                if (parts.size < 2) return null
                var h = parts[0].trim().toInt()
                val m = parts[1].trim().toInt()
                if (isPm && h != 12) h += 12
                if (!isPm && h == 12) h = 0
                hour = h; minute = m
            } else {
                val parts = clean.split(":")
                if (parts.size < 2) return null
                hour = parts[0].trim().toInt()
                minute = parts[1].trim().toInt()
            }

            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.MINUTE, 30) // +30 minutes for post-meal hydration
            }
            if (cal.timeInMillis <= System.currentTimeMillis()) {
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            cal.timeInMillis
        } catch (e: Exception) {
            null
        }
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Scheduled alarms and daily water intake reminders"
                enableVibration(true)
            }
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }
}
