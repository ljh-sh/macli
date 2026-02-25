// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "macli",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "macli", targets: ["macli"])
    ],
    targets: [
        .target(
            name: "HidSensorObjC",
            path: "Sources/HidSensorObjC",
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Foundation")
            ]
        ),
        .executableTarget(
            name: "macli",
            dependencies: ["HidSensorObjC"],
            path: "Sources",
            exclude: ["HidSensorObjC"]
        )
    ],
    cLanguageStandard: .c11
)
