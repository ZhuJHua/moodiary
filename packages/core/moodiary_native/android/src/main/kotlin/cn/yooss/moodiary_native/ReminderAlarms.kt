package cn.yooss.moodiary_native

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.time.Instant
import java.time.ZonedDateTime
import java.util.UUID
import java.util.concurrent.Executors
import kotlinx.coroutines.asCoroutineDispatcher
import org.json.JSONArray
import org.json.JSONObject

internal class ReminderAlarms(private val context: Context) {
    private val prefs = context.getSharedPreferences("diary_reminders", Context.MODE_PRIVATE)
    private val alarms = requireNotNull(context.getSystemService(AlarmManager::class.java))
    private val notifications = requireNotNull(context.getSystemService(NotificationManager::class.java))

    fun setSchedule(schedule: ReminderSchedule) {
        val now = ZonedDateTime.now()
        val toArm = mutableListOf<ArmedReminder>()
        val desired = schedule.slots.associate { slot ->
            require(slot.id in 1L..5L && slot.hour in 0L..23L && slot.minute in 0L..59L)
            require(slot.weekdays.isNotEmpty() && slot.weekdays.all { it in 1L..7L })
            val id = slot.id.toInt()
            val (trigger, arm) = ReminderScheduler.reconcile(now, slot, read(id), existingAlarm(id) != null)
            val reminder = ArmedReminder(slot, trigger)
            if (arm) toArm.add(reminder)
            id to reminder
        }
        require(desired.size == schedule.slots.size)
        if (desired.isNotEmpty()) ensureChannel(schedule.channelName)
        val edit = prefs.edit().clear().putString(CHANNEL_NAME, schedule.channelName)
        desired.forEach { (id, reminder) -> edit.putString(id.toString(), encode(reminder)) }
        for (id in SLOT_IDS - desired.keys) {
            cancelAlarm(id)
            notifications.cancel(100000 + id)
        }
        for (reminder in toArm) cancelAlarm(reminder.slot.id.toInt())
        check(edit.commit())
        toArm.forEach(::arm)
    }

    fun reschedule() {
        val now = ZonedDateTime.now()
        for (id in SLOT_IDS) {
            val reminder = read(id) ?: continue
            saveAndArm(reminder.copy(trigger = ReminderScheduler.nextTrigger(now, reminder.slot)))
        }
    }

    fun fire(id: Int, trigger: Long) {
        val reminder = read(id) ?: return
        if (reminder.trigger != trigger) return
        val now = ZonedDateTime.now()
        val afterFire = maxOf(now.toInstant(), Instant.ofEpochMilli(trigger))
            .plusSeconds(60).atZone(now.zone)
        saveAndArm(reminder.copy(trigger = ReminderScheduler.nextTrigger(afterFire, reminder.slot)))
        val channelName = requireNotNull(prefs.getString(CHANNEL_NAME, null))
        post(reminder.slot.title, reminder.slot.body, channelName, 100000 + id, 1000 + id)
    }

    fun clear() {
        check(prefs.edit().clear().commit())
        for (id in SLOT_IDS) {
            cancelAlarm(id)
            notifications.cancel(100000 + id)
        }
        notifications.cancel(TEST_ID)
    }

    fun showTest(title: String, body: String, channelName: String) =
        post(title, body, channelName, TEST_ID, 1999)

    fun isChannelEnabled() = notifications.getNotificationChannel(CHANNEL_ID)?.importance !=
        NotificationManager.IMPORTANCE_NONE

    private fun post(title: String, body: String, channelName: String, id: Int, requestCode: Int) {
        ensureChannel(channelName)
        if (!notifications.areNotificationsEnabled() || !isChannelEnabled()) return
        val launch = requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
            .setAction(ACTION_TAP).putExtra(EXTRA_TAP_ID, UUID.randomUUID().toString())
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val tap = PendingIntent.getActivity(context, requestCode, launch, UPDATE_FLAGS)
        val notification = Notification.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        notifications.notify(id, notification)
    }

    private fun ensureChannel(name: String) {
        val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT)
        channel.setShowBadge(false)
        notifications.createNotificationChannel(channel)
    }

    private fun saveAndArm(reminder: ArmedReminder) {
        check(prefs.edit().putString(reminder.slot.id.toString(), encode(reminder)).commit())
        arm(reminder)
    }

    private fun alarmIntent() = Intent(context, ReminderAlarmReceiver::class.java).setAction(ACTION_ALARM)

    private fun arm(reminder: ArmedReminder) {
        val id = reminder.slot.id.toInt()
        val intent = alarmIntent().putExtra(EXTRA_ID, id).putExtra(EXTRA_TRIGGER, reminder.trigger)
        val pending = PendingIntent.getBroadcast(context, id, intent, UPDATE_FLAGS)
        try {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, reminder.trigger, pending)
        } catch (error: RuntimeException) {
            pending.cancel()
            throw error
        }
    }

    private fun existingAlarm(id: Int): PendingIntent? = PendingIntent.getBroadcast(
        context, id, alarmIntent(), PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun cancelAlarm(id: Int) {
        val pending = existingAlarm(id) ?: return
        alarms.cancel(pending)
        pending.cancel()
    }

    private fun encode(reminder: ArmedReminder): String = with(reminder.slot) {
        JSONObject().apply {
            put("hour", hour)
            put("minute", minute)
            put("weekdays", JSONArray(weekdays))
            put("title", title)
            put("body", body)
            put("trigger", reminder.trigger)
        }.toString()
    }

    private fun read(id: Int): ArmedReminder? {
        val json = JSONObject(prefs.getString(id.toString(), null) ?: return null)
        val days = json.getJSONArray("weekdays")
        val slot = ReminderSlot(
            id = id.toLong(),
            hour = json.getLong("hour"),
            minute = json.getLong("minute"),
            weekdays = List(days.length()) { days.getLong(it) },
            title = json.getString("title"),
            body = json.getString("body"),
        )
        return ArmedReminder(slot, json.getLong("trigger"))
    }

    companion object {
        val dispatcher = Executors.newSingleThreadExecutor().asCoroutineDispatcher()
        const val ACTION_ALARM = "cn.yooss.moodiary.REMINDER_ALARM"
        const val ACTION_TAP = "cn.yooss.moodiary.REMINDER_TAP"
        const val EXTRA_TAP_ID = "moodiary_reminder_tap_id"
        const val EXTRA_ID = "slotId"
        const val EXTRA_TRIGGER = "trigger"
        private const val CHANNEL_ID = "diary_reminder"
        private const val CHANNEL_NAME = "channelName"
        private const val TEST_ID = 300000
        private val SLOT_IDS = 1..5
        private const val UPDATE_FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    }
}
