package cn.yooss.moodiary_native

import java.time.Duration
import java.time.LocalTime
import java.time.ZonedDateTime

internal object ReminderScheduler {
    private val LATE_GRACE = Duration.ofHours(2)

    fun next(now: ZonedDateTime, hour: Int, minute: Int, weekdays: Set<Int>): ZonedDateTime {
        require(weekdays.isNotEmpty() && weekdays.all { it in 1..7 })
        val time = LocalTime.of(hour, minute)
        val today = now.toLocalDate()
        return (-1L..7L).asSequence()
            .map { today.plusDays(it) }
            .filter { it.dayOfWeek.value in weekdays }
            .map { ZonedDateTime.of(it, time, now.zone) }
            .filter { it.isAfter(now) }
            .minBy { it.toInstant() }
    }

    fun reconcile(now: ZonedDateTime, slot: ReminderSlot, previous: ArmedReminder?, alarmExists: Boolean): Pair<Long, Boolean> {
        val nowMillis = now.toInstant().toEpochMilli()
        val trigger = previous?.takeIf {
            it.slot.hour == slot.hour && it.slot.minute == slot.minute && it.slot.weekdays.toSet() == slot.weekdays.toSet()
        }?.trigger
        if (trigger != null && trigger > nowMillis && alarmExists) return trigger to false
        if (trigger != null && trigger > nowMillis - LATE_GRACE.toMillis()) return trigger to true
        return nextTrigger(now, slot) to true
    }

    fun nextTrigger(now: ZonedDateTime, slot: ReminderSlot): Long =
        next(now, slot.hour.toInt(), slot.minute.toInt(), slot.weekdays.map { it.toInt() }.toSet())
            .toInstant().toEpochMilli()
}

internal data class ArmedReminder(val slot: ReminderSlot, val trigger: Long)
