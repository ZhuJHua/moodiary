import CoreLocation

// Plugin registration creates the manager on main, so Core Location delivers its delegates there.
final class DeviceLocation: NSObject, LocationApi, CLLocationManagerDelegate {
  private struct Waiter {
    let precise: Bool
    let continuation: CheckedContinuation<CLLocation?, Never>
    let deadline: DispatchWorkItem
  }

  private static let freshSeconds: TimeInterval = 10
  private static let preciseMeters: CLLocationAccuracy = 100
  private static let sameMomentSeconds: TimeInterval = 120

  private let manager = CLLocationManager()
  @MainActor private var authorizing: [CheckedContinuation<LocationAuthorization, Never>] = []
  @MainActor private var waiters: [UUID: Waiter] = [:]
  @MainActor private var candidates: [CLLocation] = []

  override init() {
    super.init()
    manager.delegate = self
  }

  @MainActor func requestPermission() async throws -> LocationAuthorization {
    if manager.authorizationStatus != .notDetermined { return authorization }
    return await withCheckedContinuation { continuation in
      authorizing.append(continuation)
      manager.requestWhenInUseAuthorization()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    // Fires once on delegate assignment too; only a decided status resolves the prompt.
    MainActor.assumeIsolated {
      guard manager.authorizationStatus != .notDetermined else { return }
      let waiting = authorizing
      authorizing = []
      waiting.forEach { $0.resume(returning: authorization) }
    }
  }

  @MainActor func isServiceEnabled() async throws -> Bool {
    // Apple warns this blocks when called on the main thread.
    await Task.detached { CLLocationManager.locationServicesEnabled() }.value
  }

  func lastKnown() throws -> LocationFix? {
    guard authorization == .granted else { return nil }
    return manager.location.map(Self.fix)
  }

  @MainActor func current(precise: Bool, timeoutMillis: Int64) async throws -> LocationFix? {
    guard authorization == .granted else { return nil }
    let location: CLLocation? = await withCheckedContinuation { continuation in
      let id = UUID()
      let first = waiters.isEmpty
      if first { candidates.removeAll() }
      let deadline = DispatchWorkItem { [weak self] in
        MainActor.assumeIsolated {
          guard let self, self.waiters[id] != nil else { return }
          self.finish(id, with: Self.best(self.candidates))
        }
      }
      waiters[id] = Waiter(precise: precise, continuation: continuation, deadline: deadline)
      updateAccuracy()
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(timeoutMillis)), execute: deadline)
      if first { manager.startUpdatingLocation() }
    }
    return location.map(Self.fix)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    MainActor.assumeIsolated {
      // Negative horizontalAccuracy marks the coordinates themselves as invalid.
      let locations = locations.filter { $0.horizontalAccuracy >= 0 }
      guard !waiters.isEmpty, !locations.isEmpty else { return }
      candidates.append(contentsOf: locations)
      let now = Date()
      let fresh = locations.filter { now.timeIntervalSince($0.timestamp) <= Self.freshSeconds }
      let ordinary = Self.best(fresh)
      let precise = Self.best(fresh.filter { $0.horizontalAccuracy > 0 && $0.horizontalAccuracy <= Self.preciseMeters })
      for (id, waiter) in waiters {
        let needsPrecision = waiter.precise && manager.accuracyAuthorization != .reducedAccuracy
        if let fix = needsPrecision ? precise : ordinary { finish(id, with: fix) }
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    MainActor.assumeIsolated {
      guard (error as? CLError)?.code != .locationUnknown else { return }
      let fallback = Self.best(candidates)
      for id in waiters.keys { finish(id, with: fallback) }
    }
  }

  @MainActor private func updateAccuracy() {
    manager.desiredAccuracy = waiters.values.contains(where: { $0.precise })
      ? kCLLocationAccuracyBest : kCLLocationAccuracyHundredMeters
  }

  @MainActor private func finish(_ id: UUID, with location: CLLocation?) {
    guard let waiter = waiters.removeValue(forKey: id) else { return }
    waiter.deadline.cancel()
    if waiters.isEmpty {
      manager.stopUpdatingLocation()
      candidates.removeAll()
    } else {
      updateAccuracy()
    }
    waiter.continuation.resume(returning: location)
  }

  /// Same rule as Android's `bestCandidate`: most accurate within two minutes of the newest.
  private static func best(_ locations: [CLLocation]) -> CLLocation? {
    guard let newest = locations.map(\.timestamp).max() else { return nil }
    return locations.filter { newest.timeIntervalSince($0.timestamp) <= sameMomentSeconds }.min { left, right in
      let lhs = left.horizontalAccuracy > 0 ? left.horizontalAccuracy : .infinity
      let rhs = right.horizontalAccuracy > 0 ? right.horizontalAccuracy : .infinity
      return lhs != rhs ? lhs < rhs : left.timestamp > right.timestamp
    }
  }

  private var authorization: LocationAuthorization {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: return .granted
    case .notDetermined: return .denied
    // iOS never prompts twice; only Settings can change a denial.
    default: return .deniedForever
    }
  }

  private static func fix(_ location: CLLocation) -> LocationFix {
    LocationFix(
      latitude: location.coordinate.latitude,
      longitude: location.coordinate.longitude,
      ageMillis: Int64(max(0, -location.timestamp.timeIntervalSinceNow) * 1000)
    )
  }
}
