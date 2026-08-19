package com.hydrotracker.hydro_flutter

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Receives the AlarmManager broadcast from BootReceiver-scheduled alarms and
 * shows the hydration reminder notification — entirely native, no Flutter needed.
 */
class AlarmNotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val notifId = intent.getIntExtra(BootReceiver.EXTRA_NOTIF_ID, 999)
        val title = intent.getStringExtra(BootReceiver.EXTRA_TITLE) ?: "\uD83D\uDCA7 Time to Hydrate!"
        val body = intent.getStringExtra(BootReceiver.EXTRA_BODY) ?: "Stay on top of your goal with a fresh glass of water."
        showNotification(context, notifId, title, body)
    }

    private fun showNotification(context: Context, notifId: Int, title: String, body: String) {
        // Tapping the notification opens the app
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPending = PendingIntent.getActivity(
            context,
            notifId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, BootReceiver.CHANNEL_ID)
        } else {
            Notification.Builder(context).apply {
                setPriority(Notification.PRIORITY_HIGH)
            }
        }

        builder
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(tapPending)

        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(notifId, builder.build())
    }
}
