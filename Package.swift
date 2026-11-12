// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MetalRack", platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "MetalRackUI", targets: ["MetalRackUI"]), .library(name: "MetalRackScene", targets: ["MetalRackScene"]), .library(name: "MetalRack", targets: ["MetalRack", "MetalRackImageProcessing"])],
    targets: [.target(name: "MetalRackUI", dependencies: ["MetalRackScene", "MetalRackServices"], exclude: ["Implementation/MROpenAL.m", "Implementation/MyOpenALSupport.c"],
                 cSettings: [.headerSearchPath("Dependencies"), .define("PROJECT_USE_FBMANAGER"), .define("PROJECT_IGNORE_POPUPMANAGER")],
                 linkerSettings: [.linkedLibrary("z"), .linkedFramework("UIKit", .when(platforms: [.iOS])), .linkedFramework("AVFoundation", .when(platforms: [.iOS])), .linkedFramework("AudioToolbox", .when(platforms: [.iOS])), .linkedFramework("GameKit", .when(platforms: [.iOS])), .linkedFramework("StoreKit", .when(platforms: [.iOS])), .linkedFramework("MessageUI", .when(platforms: [.iOS])), .linkedFramework("SystemConfiguration", .when(platforms: [.iOS]))]),
              .target(name: "MetalRackServices"),
              .target(name: "MetalRackScene", dependencies: ["MetalRackImageProcessing"], linkerSettings: [.linkedFramework("CoreGraphics"), .linkedFramework("ImageIO"), .linkedFramework("CoreText")]),
              .target(name: "MetalRackImageProcessing"),
              .target(name: "MetalRack", dependencies: ["MetalRackImageProcessing", "MetalRackScene"], resources: [.copy("Resources/QuadShaders.txt")]),
              .testTarget(name: "MetalRackServicesTests", dependencies: ["MetalRackServices"], exclude: ["README.md"], resources: [.copy("Store.storekit")]),
              .testTarget(name: "MetalRackTests", dependencies: ["MetalRack", "MetalRackImageProcessing", "MetalRackScene"])])
