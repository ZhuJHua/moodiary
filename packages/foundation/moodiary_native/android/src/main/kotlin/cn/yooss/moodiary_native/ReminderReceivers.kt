package cn.yooss.moodiary_native

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

private fun BroadcastReceiver.updateAlarms(context: Context, update: ReminderAlarms.() -> Unit) {
    val pending = goAsync()
    CoroutineScope(ReminderAlarms.dispatcher).launch {
        try {
            ReminderAlarms(context.applicationContext).update()
        } catch (error: Exception) {
            Log.e("ReminderReceivers", "Failed to update reminder alarms", error)
        } finally {
            pending.finish()
        }
    }
}

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderAlarms.ACTION_ALARM) return
        val id = intent.getIntExtra(ReminderAlarms.EXTRA_ID, 0)
        val trigger = intent.getLongExtra(ReminderAlarms.EXTRA_TRIGGER, -1)
        if (id in 1..5 && trigger >= 0) updateAlarms(context) { fire(id, trigger) }
    }
}

class ReminderRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> updateAlarms(context) { reschedule() }
        }
    }
}
