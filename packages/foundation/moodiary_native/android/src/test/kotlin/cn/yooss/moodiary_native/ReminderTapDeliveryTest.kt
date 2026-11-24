package cn.yooss.moodiary_native

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReminderTapDeliveryTest {
    @Test fun coldTapSurvivesEngineReplacementAndIsConsumedOnce() {
        val taps = ReminderTapDelivery()
        val firstEngine = { error("detached engine received a tap") }
        var liveCount = 0
        val newEngine: () -> Unit = { liveCount++ }
        taps.receive("first", null) { true }
        taps.detach(firstEngine)
        assertTrue(taps.start(newEngine))
        assertFalse(taps.start(newEngine))
        assertEquals(0, liveCount)
        taps.receive("second", "first") { true }
        assertEquals(1, liveCount)
        assertFalse(taps.start(newEngine))
        taps.detach(newEngine)
        taps.receive("third", "second") { true }
        assertTrue(taps.start(newEngine))
        assertEquals(1, liveCount)
    }

    @Test fun restoredProcessIgnoresConsumedTapAndDeliversTheNextPost() {
        var lastConsumed: String? = null
        val persist: (String) -> Boolean = { id ->
            lastConsumed = id
            true
        }
        ReminderTapDelivery().receive("first", lastConsumed, persist)
        val restored = ReminderTapDelivery()
        restored.receive("first", lastConsumed) { error("replayed tap written again") }
        var delivered = 0
        assertFalse(restored.start {
            assertEquals("second", lastConsumed)
            delivered++
        })
        restored.receive("second", lastConsumed, persist)
        assertEquals(1, delivered)
    }
}
