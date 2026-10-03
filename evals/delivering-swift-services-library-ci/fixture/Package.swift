// swift-tools-version: 6.3
import PackageDescription
let package = Package(
    name: "LibraryCore",
    products: [.library(name: "LibraryCore", targets: ["LibraryCore"])],
    targets: [.target(name: "LibraryCore"), .testTarget(name: "LibraryCoreTests", dependencies: ["LibraryCore"])],
    swiftLanguageModes: [.v6]
)
