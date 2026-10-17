// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MetalRack", platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "MetalRack", targets: ["MetalRack"])],
    targets: [.target(name: "MetalRack", resources: [.copy("Resources/QuadShaders.txt")]),
              .testTarget(name: "MetalRackTests", dependencies: ["MetalRack"])])
