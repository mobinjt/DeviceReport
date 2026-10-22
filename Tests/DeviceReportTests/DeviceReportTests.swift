import Foundation
import Synchronization
import Testing
import UserNotifications
@testable import DeviceReport

struct ClientDeviceTests {
    @Test func reportsAreCleanedBeforeTheyAreKept() {
        let device = ClientDevice(
            system: .iOS, model: " iPhone17,1\u{7}", systemVersion: "26.0", appVersion: String(repeating: "9", count: 60),
            appBuild: "42", appLanguage: "fa", notifications: .quiet
        ).sanitized
        #expect(device.model == "iPhone17,1", "Control characters and surrounding spaces go")
        #expect(device.appVersion.count == ClientDevice.maximumFieldLength)
        #expect(device.notifications == .quiet)
    }

    @Test func theWireFormatUsesShortNames() throws {
        let device = ClientDevice(system: .iPadOS, model: "iPad16,3", systemVersion: "26.0", appVersion: "1.0", appBuild: "9", appLanguage: "en", notifications: .on)
        let json = String(decoding: try JSONEncoder().encode(device), as: UTF8.self)
        #expect(json.contains(#""system":"ipados""#) && json.contains(#""notifications":"on""#))
    }

    @MainActor
    @Test func theCurrentDeviceIsFilledIn() {
        let device = ClientDevice.current(notifications: .off)
        #expect(!device.model.isEmpty)
        #expect(device.systemVersion.split(separator: ".").count >= 2)
        #expect(device == device.sanitized)
        #if os(macOS)
        #expect(device.system == .macOS)
        #endif
    }

    @Test func notificationsFollowThePermissionAndTheAppsSwitch() {
        #expect(ClientDevice.Notifications(authorization: .authorized) == .on)
        #expect(ClientDevice.Notifications(authorization: .provisional) == .quiet)
        #expect(ClientDevice.Notifications(authorization: .denied) == .off)
        #expect(ClientDevice.Notifications(authorization: .notDetermined) == .off)
        #expect(ClientDevice.Notifications(authorization: .authorized, isEnabledInApp: false) == .off)
    }
}

@MainActor
struct DeviceReporterTests {
    private struct Offline: Error {}

    private func device(build: String) -> ClientDevice {
        ClientDevice(system: .iOS, model: "iPhone17,1", systemVersion: "26.0", appVersion: "1.0", appBuild: build, appLanguage: "en", notifications: .on)
    }

    @Test func aDeviceIsSentOnceUntilSomethingChanges() async {
        let sent = Mutex<[ClientDevice]>([])
        let reporter = DeviceReporter { device in sent.withLock { $0.append(device) } }
        await reporter.report(device(build: "1"))
        await reporter.report(device(build: "1"))
        #expect(sent.withLock { $0.count } == 1)
        await reporter.report(device(build: "2"))
        #expect(sent.withLock { $0.map(\.appBuild) } == ["1", "2"])
    }

    @Test func aFailedReportIsTriedAgain() async {
        let attempts = Mutex(0)
        let reporter = DeviceReporter { _ in
            let attempt = attempts.withLock { $0 += 1; return $0 }
            if attempt == 1 { throw Offline() }
        }
        await reporter.report(device(build: "1"))
        await reporter.report(device(build: "1"))
        await reporter.report(device(build: "1"))
        #expect(attempts.withLock { $0 } == 2, "Sent again after the failure, then not again")
    }
}
