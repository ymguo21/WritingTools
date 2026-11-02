import AppKit
import CoreGraphics

private let logger = AppLogger.logger("ScreenRegionCapture")

enum ScreenRegionCaptureError: LocalizedError {
  case permissionDenied
  case captureFailed(String)

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      return "Screen Recording permission is required to capture a region of the screen. Allow Writing Tools in System Settings > Privacy & Security > Screen Recording, then try again."
    case .captureFailed(let reason):
      return "Could not capture the screen: \(reason)"
    }
  }
}

/// Lets the user drag out a region of the screen and returns it as PNG data,
/// using the system's own `screencapture` crosshair.
enum ScreenRegionCapture {
  /// Whether the app may capture the screen. Asks the system the first time,
  /// which also lists the app in the Screen Recording settings.
  @MainActor
  static func ensurePermission() -> Bool {
    if CGPreflightScreenCaptureAccess() { return true }
    _ = CGRequestScreenCaptureAccess()
    return false
  }

  /// Returns the captured PNG, or nil when the user cancels with Esc.
  static func captureRegion() async throws -> Data? {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("writingtools-capture-\(UUID().uuidString).png")
    defer { try? FileManager.default.removeItem(at: url) }

    // -i: interactive selection, -x: no shutter sound.
    let status = try await run(arguments: ["-i", "-x", "-t", "png", url.path])
    guard status == 0 else {
      throw ScreenRegionCaptureError.captureFailed("screencapture exited with status \(status)")
    }

    // Cancelling leaves no file behind.
    guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
    logger.debug("Captured region (\(data.count) bytes)")
    return data
  }

  private static func run(arguments: [String]) async throws -> Int32 {
    try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
      process.arguments = arguments
      process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
      do {
        try process.run()
      } catch {
        continuation.resume(throwing: ScreenRegionCaptureError.captureFailed(error.localizedDescription))
      }
    }
  }
}
