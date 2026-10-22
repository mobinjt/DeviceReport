// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DeviceReport",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        /// The reporter apps use: the device it runs on, sent when something changed.
        .library(name: "DeviceReport", targets: ["DeviceReport"]),
        /// The device model alone, Foundation only, for servers and tools (Linux included).
        .library(name: "DeviceReportCore", targets: ["DeviceReportCore"])
    ],
    targets: [
        .target(name: "DeviceReportCore"),
        .target(name: "DeviceReport", dependencies: ["DeviceReportCore"]),
        .testTarget(name: "DeviceReportTests", dependencies: ["DeviceReport"])
    ]
)
