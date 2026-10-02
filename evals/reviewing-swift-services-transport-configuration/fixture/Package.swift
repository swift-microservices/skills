// swift-tools-version: 6.3
import PackageDescription

// Target inventory only; dependencies and settings are omitted from this excerpt.
let package = Package(
    name: "acme-billing",
    products: [.executable(name: "billing", targets: ["Billing"])],
    targets: [
        .target(name: "BillingCore"),
        .target(name: "BillingPostgres"),
        .target(name: "BillingGRPC"),
        .target(name: "BillingWorkflows"),
        .executableTarget(name: "Billing"),
    ]
)
