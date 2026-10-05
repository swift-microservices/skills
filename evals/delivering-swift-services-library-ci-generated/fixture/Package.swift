// swift-tools-version: 6.3
import PackageDescription
let package = Package(
    name: "ExampleSDK",
    platforms: [.macOS(.v15)],
    products: [.library(name: "ExampleSDK", targets: ["ExampleSDK"])],
    traits: [.trait(name: "URLSessionTransport"), .default(enabledTraits: ["URLSessionTransport"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.13.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.12.1"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0")
    ],
    targets: [.target(
        name: "ExampleSDK",
        dependencies: [
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession", condition: .when(traits: ["URLSessionTransport"]))
        ],
        plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
    )],
    swiftLanguageModes: [.v6]
)
