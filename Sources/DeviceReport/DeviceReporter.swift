@_exported import DeviceReportCore
import Foundation
import OSLog
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Tells the app's backend about this device, sending only when something changed since the last
/// report this launch. How to send is passed in, so any backend works; a failed send is tried
/// again on the next report.
@MainActor
public final class DeviceReporter {
    private let send: @Sendable (ClientDevice) async throws -> Void
    private var lastSent: ClientDevice?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DeviceReport", category: "device")

    /// - Parameter send: delivers a report to the backend; throwing means it wasn't delivered.
    public init(send: @escaping @Sendable (ClientDevice) async throws -> Void) {
        self.send = send
    }

    /// Reports the device the app runs on, with the notification state the app knows.
    public func report(notifications: ClientDevice.Notifications) async {
        await report(.current(notifications: notifications))
    }

    /// Reports `device` unless it was the last one sent.
    public func report(_ device: ClientDevice) async {
        guard device != lastSent else { return }
        do {
            try await send(device)
            lastSent = device
        } catch {
            logger.notice("Device not reported: \(String(describing: error), privacy: .public)")
        }
    }
}

extension ClientDevice {
    /// The device the app runs on: its system, model, system and app versions and the app's
    /// language, sanitized. On the main actor, where UIKit tells the device's idiom.
    @MainActor
    public static func current(notifications: Notifications, bundle: Bundle = .main) -> ClientDevice {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return ClientDevice(
            system: currentSystem,
            model: currentModel,
            systemVersion: "\(version.majorVersion).\(version.minorVersion)" + (version.patchVersion > 0 ? ".\(version.patchVersion)" : ""),
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            appBuild: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "",
            appLanguage: bundle.preferredLocalizations.first ?? "en",
            notifications: notifications
        ).sanitized
    }

    @MainActor
    private static var currentSystem: System {
        #if os(macOS)
        .macOS
        #elseif os(visionOS)
        .visionOS
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? .iPadOS : .iOS
        #endif
    }

    /// The hardware model, such as `iPhone17,1`; in the simulator, the simulated device's.
    private static var currentModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &bytes, &size, nil, 0)
        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        #else
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #endif
    }
}

extension ClientDevice.Notifications {
    /// From the system's permission, and whether the app's own switch for notifications is on.
    public init(authorization: UNAuthorizationStatus, isEnabledInApp: Bool = true) {
        guard isEnabledInApp else {
            self = .off
            return
        }
        self = switch authorization {
        case .authorized, .ephemeral: .on
        case .provisional: .quiet
        default: .off
        }
    }
}
