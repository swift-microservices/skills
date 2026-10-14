#!/bin/bash
set -euo pipefail
mkdir -p Sources/BillingCore Tests/BillingCoreTests
cat > Package.swift <<'SWIFT'
// swift-tools-version: 6.3
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "acme-billing",
    platforms: [.macOS(.v15)],
    products: [.library(name: "BillingCore", targets: ["BillingCore"])],
    targets: [
        .target(name: "BillingCore", swiftSettings: swiftSettings),
        .testTarget(name: "BillingCoreTests", dependencies: [
            "BillingCore",
        ], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > Sources/BillingCore/InvoiceText.swift <<'SWIFT'
import Foundation

/// The machine-readable text an invoice carries on the wire and in exported files.
package enum InvoiceText {
    /// The issue timestamp in UTC, for example `2026-10-14T09:30:00Z`.
    package static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    /// The due date as a calendar day in UTC, for example `2026-11-13`.
    package static func dueDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Parses a due date written as `yyyy-MM-dd` to midnight UTC; nil for anything else.
    package static func dueDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }

    /// An amount in cents as a decimal with two fraction digits and no grouping, for example
    /// `123456` as `1234.56` and `-5` as `-0.05`.
    package static func amount(cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "0.00"
    }

    /// The invoice number with six zero-padded digits, for example `7` as `INV-000007`.
    package static func number(_ value: Int) -> String {
        String(format: "INV-%06d", value)
    }
}
SWIFT
cat > Tests/BillingCoreTests/InvoiceTextTests.swift <<'SWIFT'
import BillingCore
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite struct InvoiceTextTests {
    let issued = Date(timeIntervalSince1970: 1_791_970_200)
    let due = Date(timeIntervalSince1970: 1_794_528_000)

    @Test func timestamp() {
        #expect(InvoiceText.timestamp(issued) == "2026-10-14T09:30:00Z")
    }

    @Test func dueDateRoundTrips() {
        #expect(InvoiceText.dueDateText(due) == "2026-11-13")
        #expect(InvoiceText.dueDate("2026-11-13") == due)
    }

    @Test func dueDateRejectsOtherText() {
        #expect(InvoiceText.dueDate("13/11/2026") == nil)
        #expect(InvoiceText.dueDate("") == nil)
    }

    @Test func amount() {
        #expect(InvoiceText.amount(cents: 123_456) == "1234.56")
        #expect(InvoiceText.amount(cents: 7) == "0.07")
        #expect(InvoiceText.amount(cents: -5) == "-0.05")
        #expect(InvoiceText.amount(cents: 0) == "0.00")
    }

    @Test func number() {
        #expect(InvoiceText.number(7) == "INV-000007")
        #expect(InvoiceText.number(1_234_567) == "INV-1234567")
    }
}
SWIFT
