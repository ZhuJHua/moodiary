package cn.yooss.moodiary_native

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LocationRankingTest {
    private fun fix(ageMillis: Long, accuracy: Float?) = LocationCandidate(ageMillis, accuracy, 0.0, 0.0)

    @Test fun emptyHasNoBest() {
        assertNull(bestCandidate(emptyList()))
    }

    @Test fun prefersAccuracyWithinTwoMinutesOfNewest() {
        val newest = fix(1_000, 80f)
        val edge = fix(121_000, 20f)
        val tooOld = fix(121_001, 1f)
        assertEquals(edge, bestCandidate(listOf(newest, edge, tooOld)))
    }

    @Test fun resultDoesNotDependOnProviderOrder() {
        val candidates = listOf(fix(1_000, 80f), fix(121_000, 20f), fix(121_001, 1f), fix(5_000, null))
        val expected = bestCandidate(candidates)
        for (rotation in candidates.indices) {
            val rotated = candidates.drop(rotation) + candidates.take(rotation)
            assertEquals(expected, bestCandidate(rotated))
            assertEquals(expected, bestCandidate(rotated.reversed()))
        }
    }

    @Test fun unknownAccuracyRanksLast() {
        val known = fix(20, 100f)
        assertEquals(known, bestCandidate(listOf(fix(0, null), fix(1, 0f), fix(2, -1f), known)))
    }

    @Test fun equalAccuracyGoesToTheNewer() {
        val newer = fix(10, 50f)
        assertEquals(newer, bestCandidate(listOf(fix(30, 50f), newer)))
        assertEquals(fix(0, null), bestCandidate(listOf(fix(2, null), fix(0, null))))
    }
}
