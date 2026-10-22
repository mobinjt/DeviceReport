/// What an app tells its backend about the device it runs on, so the people running it can help a
/// user and see which systems and app versions are in use. Nothing that identifies the device: its
/// model, its system and app versions, the app's language, and whether notifications are on.
public struct ClientDevice: Codable, Hashable, Sendable {
    /// Longer values are cut to this length.
    public static let maximumFieldLength = 40

    public enum System: String, Codable, Hashable, Sendable {
        case iOS = "ios"
        case iPadOS = "ipados"
        case macOS = "macos"
        case visionOS = "visionos"
        case android
    }

    public enum Notifications: String, Codable, Hashable, Sendable {
        /// Off in the app or in the system's settings.
        case off
        /// Allowed quietly (Apple's provisional permission): they arrive in Notification Center.
        case quiet
        case on
    }

    public let system: System
    /// The hardware model, such as `iPhone17,1` or `Mac15,3` (Android: `Pixel 9`).
    public let model: String
    /// Such as `26.0.1`.
    public let systemVersion: String
    /// Such as `1.0`.
    public let appVersion: String
    /// Such as `42`.
    public let appBuild: String
    /// The app's language (`fa`, `en`…).
    public let appLanguage: String
    public let notifications: Notifications

    public init(
        system: System, model: String, systemVersion: String, appVersion: String, appBuild: String, appLanguage: String,
        notifications: Notifications
    ) {
        self.system = system
        self.model = model
        self.systemVersion = systemVersion
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.appLanguage = appLanguage
        self.notifications = notifications
    }

    /// The same device with every text trimmed to printable characters and `maximumFieldLength`.
    /// A backend keeps only sanitized reports.
    public var sanitized: ClientDevice {
        ClientDevice(
            system: system,
            model: Self.clean(model),
            systemVersion: Self.clean(systemVersion),
            appVersion: Self.clean(appVersion),
            appBuild: Self.clean(appBuild),
            appLanguage: Self.clean(appLanguage),
            notifications: notifications
        )
    }

    private static func clean(_ text: String) -> String {
        let printable = text.unicodeScalars.filter { $0.value >= 0x20 && $0.value < 0x7F }.map(Character.init)
        let trimmed = printable.drop { $0 == " " }.reversed().drop { $0 == " " }.reversed()
        return String(trimmed.prefix(maximumFieldLength))
    }
}
