// swift-tools-version: 6.0
import PackageDescription

// The same production preference/permission code is tested on macOS without
// requiring an iOS runtime. iOS UI tests remain in the Xcode scheme.
let package = Package(
    name: "LeanoraFoundation",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [.library(name: "LeanoraFoundation", targets: ["Leanora"])],
    targets: [
        .target(name: "Leanora", path: "ios/Leanora", exclude: ["App", "Design", "Features", "Resources/Assets.xcassets", "Resources/Info.plist", "Resources/Localizable.xcstrings", "Resources/PrivacyInfo.xcprivacy", "Leanora.entitlements"], sources: [
            "Core/Preferences/AppPreferences.swift",
            "Core/Notifications/NotificationPermissionService.swift",
            "Core/Notifications/WorkoutNotificationService.swift",
            "Core/Notifications/TrainingReminderService.swift",
            "Core/Domain",
            "Core/Persistence",
            "Core/Backup",
            "Core/Training",
            "Core/Analytics",
            "Core/Nutrition",
            "Integrations/HealthKit/HealthAuthorizationService.swift"
        ], resources: [.copy("Resources/Catalog")]),
        .testTarget(name: "LeanoraFoundationTests", dependencies: ["Leanora"], path: "ios/LeanoraTests")
    ]
)
