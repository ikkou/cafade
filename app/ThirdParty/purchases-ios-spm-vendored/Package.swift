// swift-tools-version:5.9

import PackageDescription

// Cafade uses the RevenueCat client library only. The upstream package also
// contains UI and test products, so this local manifest keeps the shipped
// dependency focused on the product the app links.
let package = Package(
    name: "RevenueCat",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "RevenueCat", targets: ["RevenueCat"])
    ],
    targets: [
        .target(
            name: "RevenueCat",
            path: "Sources",
            exclude: [
                "Info.plist",
                "LocalReceiptParsing/ReceiptParser-only-files"
            ],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
