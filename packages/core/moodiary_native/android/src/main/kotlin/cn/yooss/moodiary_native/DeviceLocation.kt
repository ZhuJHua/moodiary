package cn.yooss.moodiary_native

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.SystemClock
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.location.LocationListenerCompat
import androidx.core.location.LocationManagerCompat
import androidx.core.location.LocationRequestCompat
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import android.location.Location as AndroidLocation

/** One-shot location on the platform LocationManager only, so the app needs no Play services. */
internal class DeviceLocation(private val context: Context) : LocationApi,
    PluginRegistry.RequestPermissionsResultListener {
    var activity: Activity? = null
    private var pending: CompletableDeferred<LocationAuthorization>? = null
    private val manager = requireNotNull(context.getSystemService(LocationManager::class.java))

    override suspend fun requestPermission(): LocationAuthorization {
        if (granted()) return LocationAuthorization.GRANTED
        val host = activity ?: return LocationAuthorization.DENIED
        pending?.let { return it.await() }
        val result = CompletableDeferred<LocationAuthorization>()
        pending = result
        try {
            ActivityCompat.requestPermissions(host, PERMISSIONS, REQUEST_CODE)
        } catch (error: Exception) {
            pending = null
            result.completeExceptionally(error)
        }
        return result.await()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        finish(
            when {
                grantResults.isEmpty() -> LocationAuthorization.DENIED
                grantResults.any { it == PackageManager.PERMISSION_GRANTED } -> LocationAuthorization.GRANTED
                // Right after a denial, no rationale means the system will not ask again.
                activity?.let { host -> PERMISSIONS.none { ActivityCompat.shouldShowRequestPermissionRationale(host, it) } } == true ->
                    LocationAuthorization.DENIED_FOREVER
                else -> LocationAuthorization.DENIED
            },
        )
        return true
    }

    fun finish(result: LocationAuthorization = LocationAuthorization.DENIED) {
        val deferred = pending
        pending = null
        deferred?.complete(result)
    }

    override suspend fun isServiceEnabled() = LocationManagerCompat.isLocationEnabled(manager)

    @SuppressLint("MissingPermission")
    override fun lastKnown(): LocationFix? {
        if (!granted()) return null
        val locations = manager.allProviders
            .mapNotNull { provider -> runCatching { manager.getLastKnownLocation(provider) }.getOrNull() }
        // Drop what Dart will reject anyway, so an expired fix cannot outrank a usable one.
        val now = SystemClock.elapsedRealtimeNanos()
        return bestFix(locations.filter { now - it.elapsedRealtimeNanos < MAX_CACHED_AGE_NANOS })
    }

    @SuppressLint("MissingPermission")
    override suspend fun current(precise: Boolean, timeoutMillis: Long): LocationFix? {
        if (!granted()) return null
        val providers = if (Build.VERSION.SDK_INT >= 31 && manager.isProviderEnabled(LocationManager.FUSED_PROVIDER)) {
            listOf(LocationManager.FUSED_PROVIDER)
        } else buildList {
            if (fineGranted() && manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) add(LocationManager.GPS_PROVIDER)
            if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) add(LocationManager.NETWORK_PROVIDER)
        }
        if (providers.isEmpty()) return null
        // Approximate-only grants are fudged to >= 200 m, so they can never meet the precise bar.
        val wantsPrecision = precise && fineGranted()
        val listeners = mutableListOf<LocationListenerCompat>()
        val quality = if (wantsPrecision) LocationRequestCompat.QUALITY_HIGH_ACCURACY else LocationRequestCompat.QUALITY_BALANCED_POWER_ACCURACY
        val request = LocationRequestCompat.Builder(0L).setQuality(quality).build()
        val locations = mutableListOf<AndroidLocation>()
        val executor = ContextCompat.getMainExecutor(context)
        return try {
            withTimeoutOrNull(timeoutMillis) {
                suspendCancellableCoroutine<LocationFix?> { cont ->
                    val active = providers.toMutableSet()
                    fun exhaust(provider: String) {
                        if (cont.isActive && active.remove(provider) && active.isEmpty()) {
                            cont.resumeWith(Result.success(bestFix(locations)))
                        }
                    }
                    for (provider in providers) {
                        if (!cont.isActive) break
                        val listener = object : LocationListenerCompat {
                            override fun onLocationChanged(location: AndroidLocation) {
                                if (!cont.isActive || provider !in active) return
                                locations.add(location)
                                val candidate = location.candidate(SystemClock.elapsedRealtimeNanos())
                                val accurate = candidate.accuracyMeters?.let { it > 0 && it <= PRECISE_METERS } == true
                                if (candidate.ageMillis <= FRESH_MILLIS && (!wantsPrecision || accurate)) {
                                    cont.resumeWith(Result.success(candidate.toFix()))
                                }
                            }

                            override fun onProviderDisabled(provider: String) = exhaust(provider)
                        }
                        try {
                            LocationManagerCompat.requestLocationUpdates(manager, provider, request, executor, listener)
                            listeners.add(listener)
                        } catch (_: SecurityException) {
                            exhaust(provider)
                        } catch (_: IllegalArgumentException) {
                            exhaust(provider)
                        }
                    }
                }
            } ?: bestFix(locations)
        } finally {
            listeners.forEach { LocationManagerCompat.removeUpdates(manager, it) }
        }
    }

    private fun fineGranted() =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun granted() = fineGranted() ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun bestFix(locations: List<AndroidLocation>): LocationFix? {
        val now = SystemClock.elapsedRealtimeNanos()
        return bestCandidate(locations.map { it.candidate(now) })?.toFix()
    }

    private fun AndroidLocation.candidate(now: Long) = LocationCandidate(
        ageMillis = (now - elapsedRealtimeNanos).coerceAtLeast(0) / 1_000_000,
        accuracyMeters = accuracy.takeIf { hasAccuracy() },
        latitude = latitude, longitude = longitude,
    )

    private fun LocationCandidate.toFix() = LocationFix(latitude, longitude, ageMillis)

    private companion object {
        const val REQUEST_CODE = 0x4d53
        const val FRESH_MILLIS = 10_000L
        const val PRECISE_METERS = 100f
        const val MAX_CACHED_AGE_NANOS = 3_600_000_000_000L
        val PERMISSIONS = arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
    }
}
