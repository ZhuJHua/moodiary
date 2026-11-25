package cn.yooss.moodiary_native

internal data class LocationCandidate(
    val ageMillis: Long,
    val accuracyMeters: Float?,
    val latitude: Double,
    val longitude: Double,
)

private const val SAME_MOMENT_MILLIS = 120_000L

/**
 * The most accurate fix among those within two minutes of the newest; unknown accuracy ranks
 * last, ties go to the newer fix. Order-independent, so provider order cannot change the result.
 */
internal fun bestCandidate(candidates: List<LocationCandidate>): LocationCandidate? {
    val newest = candidates.minOfOrNull { it.ageMillis } ?: return null
    return candidates.filter { it.ageMillis - newest <= SAME_MOMENT_MILLIS }.minWithOrNull(
        compareBy<LocationCandidate> { it.accuracyMeters?.takeIf { meters -> meters > 0 } ?: Float.POSITIVE_INFINITY }
            .thenBy { it.ageMillis },
    )
}
