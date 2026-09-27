#!/bin/bash
set -euo pipefail
case_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$case_dir/../building-swift-services-swift-settings/scaffold.sh"
python3 - <<'PY'
from pathlib import Path
p = Path('Package.swift')
s = p.read_text().replace('let package = Package(', '''let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(''')
s = s.replace('.target(name: "UtilityCore")', '.target(name: "UtilityCore", swiftSettings: swiftSettings)')
s = s.replace('.target(name: "UtilityAdapter", dependencies: ["UtilityCore"])', '.target(name: "UtilityAdapter", dependencies: ["UtilityCore"], swiftSettings: swiftSettings)')
p.write_text(s)
PY
cat >> Sources/UtilityAdapter/InlineRunner.swift <<'SWIFT'

final class LocalState { var count = 0 }

actor Caller {
    private let state = LocalState()
    func increment() async -> Int {
        await InlineRunner().run {
            self.state.count += 1
            await Task.yield()
            return self.state.count
        }
    }
}
SWIFT
