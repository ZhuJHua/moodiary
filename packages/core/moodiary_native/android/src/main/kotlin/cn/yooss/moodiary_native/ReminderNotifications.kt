package cn.yooss.moodiary_native

import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal class ReminderNotifications(context: Context, private val events: ReminderNotificationsEvents) : ReminderNotificationsApi {
    private val alarms = ReminderAlarms(context)
    private val tapPrefs = context.getSharedPreferences("diary_reminder_taps", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val deliver: () -> Unit = {
        scope.launch {
            try {
                events.onTap()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                Log.w("ReminderNotifications", "Failed to deliver reminder tap", error)
            }
        }
    }

    override suspend fun setSchedule(schedule: ReminderSchedule) =
        withContext(ReminderAlarms.dispatcher) { alarms.setSchedule(schedule) }

    override suspend fun clear() = withContext(ReminderAlarms.dispatcher) { alarms.clear() }

    override suspend fun showTest(title: String, body: String, channelName: String) =
        withContext(ReminderAlarms.dispatcher) { alarms.showTest(title, body, channelName) }

    override fun isChannelEnabled() = alarms.isChannelEnabled()

    override fun consumeLaunchTap() = taps.start(deliver)

    fun takeTap(intent: Intent): Boolean {
        if (intent.action != ReminderAlarms.ACTION_TAP) return false
        val tapId = intent.getStringExtra(ReminderAlarms.EXTRA_TAP_ID)
        intent.action = Intent.ACTION_MAIN
        intent.removeExtra(ReminderAlarms.EXTRA_TAP_ID)
        if (tapId == null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return true
        taps.receive(tapId, tapPrefs.getString(LAST_TAP, null)) { id ->
            tapPrefs.edit().putString(LAST_TAP, id).commit()
        }
        return true
    }

    fun detach() {
        taps.detach(deliver)
        scope.cancel()
    }

    private companion object {
        const val LAST_TAP = "lastConsumedId"
        val taps = ReminderTapDelivery()
    }
}
