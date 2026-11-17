import Foundation

class LocalTimeZone: LocalTimeZoneApi {
  func localTimeZoneId() throws -> String { TimeZone.current.identifier }
}
