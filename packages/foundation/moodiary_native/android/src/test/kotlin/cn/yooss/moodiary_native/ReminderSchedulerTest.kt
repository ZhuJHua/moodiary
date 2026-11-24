package cn.yooss.moodiary_native

import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

class ReminderSchedulerTest {
    private fun checkNext(now: String, hour: Int, minute: Int, days: Set<Int>, expected: String) {
        assertEquals(ZonedDateTime.parse(expected), ReminderScheduler.next(ZonedDateTime.parse(now), hour, minute, days))
    }

    @Test fun sameDayFuture() = checkNext("2027-03-22T08:00Z", 8, 30, setOf(1), "2027-03-22T08:30Z")

    @Test fun sameDayPastUsesNextSelectedDay() =
        checkNext("2027-03-22T08:31Z", 8, 30, setOf(1, 4), "2027-03-25T08:30Z")

    @Test fun exactTimeIsAlreadyDue() = checkNext("2027-03-22T08:30Z", 8, 30, setOf(1), "2027-03-29T08:30Z")

    @Test fun springGapShiftsForward() = checkNext(
        "2027-03-14T00:00-05:00[America/New_York]", 2, 30, setOf(7), "2027-03-14T03:30-04:00[America/New_York]",
    )

    @Test fun fallOverlapUsesFirstOffset() = checkNext(
        "2027-11-07T00:00-04:00[America/New_York]", 1, 30, setOf(7), "2027-11-07T01:30-04:00[America/New_York]",
    )

    @Test fun fallOverlapSkipsSecondOccurrence() = checkNext(
        "2027-11-07T01:45-04:00[America/New_York]", 1, 30, setOf(7), "2027-11-14T01:30-05:00[America/New_York]",
    )

    @Test fun midnightGapStillBelongsToSaturday() = checkNext(
        "2027-03-28T00:10-01:00[America/Nuuk]", 23, 30, setOf(6), "2027-03-28T00:30-01:00[America/Nuuk]",
    )

    @Test fun kolkataUsesLocalTime() = checkNext(
        "2027-03-22T07:00+05:30[Asia/Kolkata]", 8, 30, setOf(1), "2027-03-22T08:30+05:30[Asia/Kolkata]",
    )

    private val now = ZonedDateTime.parse("2027-03-22T09:30Z")
    private val slot = ReminderSlot(1, 8, 30, listOf(1, 4), "title", "body")
    private fun at(time: ZonedDateTime) = time.toInstant().toEpochMilli()
    private val next = at(ZonedDateTime.parse("2027-03-25T08:30Z"))

    @Test fun unchangedFutureAlarmIsLeftAlone() {
        val trigger = at(now.plusDays(1))
        val updated = slot.copy(title = "new title", weekdays = listOf(4, 1))
        assertEquals(trigger to false, ReminderScheduler.reconcile(now, updated, ArmedReminder(slot, trigger), true))
        assertEquals(trigger to true, ReminderScheduler.reconcile(now, slot, ArmedReminder(slot, trigger), false))
    }

    @Test fun recentlyDueTriggerIsRearmedEvenIfItsAlarmLooksAlive() {
        val trigger = at(now.minusHours(1))
        assertEquals(trigger to true, ReminderScheduler.reconcile(now, slot, ArmedReminder(slot, trigger), true))
    }

    @Test fun staleEditedOrNewSlotsGetTheNextOccurrence() {
        val stale = ArmedReminder(slot, at(now.minusHours(3)))
        assertEquals(next to true, ReminderScheduler.reconcile(now, slot, stale, true))
        assertEquals(next to true, ReminderScheduler.reconcile(now, slot, null, true))
        val current = ArmedReminder(slot.copy(minute = 45), at(now.plusDays(1)))
        assertEquals(next to true, ReminderScheduler.reconcile(now, slot, current, true))
    }
}
