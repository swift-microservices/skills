# Standard Swift library CI

This is the recommended CI pipeline for modern Swift libraries and the required standard for
**all libraries used in swift-microservices server development**, including project-owned Core,
contracts, SDKs, and adapters. Apply it as-is, adapting product names and documented capability
exceptions. Repository `AGENTS.md` supplies the project profile and can override general decisions;
record the reason and replacement coverage for each exception. Existing drift is not an exception.
Executable/application delivery lives in [delivery.md](delivery.md).

## Contents

- [Events and gates](#events-and-gates)
- [Compiler matrix](#compiler-matrix)
- [Soundness and documentation](#soundness-and-documentation)
- [Formatting and headers](#formatting-and-headers)
- [Dependency resolution and workflow references](#dependency-resolution-and-workflow-references)
- [Capability exceptions](#capability-exceptions)
- [Private organization libraries](#private-organization-libraries)
- [Validation and completion](#validation-and-completion)

## Events and gates

| Gate | Pull requests | Main pushes |
| --- | --- | --- |
| Soundness: format, headers, DocC, scripts/YAML, hygiene | Yes | No |
| Debug tests or meaningful build/consumer replacement | Yes | Yes |
| Optimized release builds | Yes | Yes |
| Static Linux SDK: released + main SDK, x86_64 musl | Yes | No |
| Foundation consumer linking, where supported | Yes | Yes |
| Exactly one SemVer impact label | Yes, also label changes | No |

There are **no scheduled workflow runs**, no API-breakage job, no macOS job, and no deployable
images, deployment credentials, or deployment branches. Dependabot's weekly update schedule is
separate from CI scheduling. PR code gates use `opened`, `reopened`, `synchronize`; the label gate
also uses `labeled`, `unlabeled`. Main means `push.branches: [main]`.

Copy the templates into these destinations and replace the DocC target name:

- [the PR template](../assets/library-pull-request.yml) → `.github/workflows/pull_request.yml`
- [the main template](../assets/library-main.yml) → `.github/workflows/main.yml`
- [the label workflow](../assets/library-pr-label.yml) → `.github/workflows/pull_request_label.yml`
- [the Dependabot configuration](../assets/library-dependabot.yml) → `.github/dependabot.yml`
- where a capability exception replaces the unit-test matrix (below), the reusable
  [PostgreSQL test template](../assets/library-postgres-tests.yml) → `.github/workflows/tests.yml`
  or [build template](../assets/library-builds.yml) → `.github/workflows/builds.yml`, called from
  both `pull_request.yml` and `main.yml` (`uses: ./.github/workflows/tests.yml`) in place of the
  `unit-tests` job
Keep independent gates independent: do not add `needs: static-sdk` or cancellation wrappers
around unrelated checks. Required merge checks should cover stable toolchains and applicable
quality/integration gates. Snapshots remain visible and advisory unless explicitly required.
Changing workflow YAML does not configure branch protection; verify/report that separately.

## Compiler matrix

Use `apple/swift-nio/.github/workflows/unit_tests.yml@main` and
`release_builds.yml@main`. They are reusable CI machinery, not a SwiftNIO source dependency;
SwiftPM still runs Swift Testing/XCTest. They supply evolving Linux compiler matrices and
release/static builds, which is why this profile uses them rather than substituting the
Swift.org package-test action. Swift.org supplies the soundness workflow.

The current tools floor is **6.3**. Set `minimum_swift_version: "6.3"` and
`linux_6_2_enabled: false` in both test and release jobs. Cover Swift 6.3, 6.4, nightly next,
and nightly main. Preserve these test overrides:

```yaml
linux_6_3_arguments_override: "-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable"
linux_6_4_arguments_override: "-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable"
linux_nightly_next_arguments_override: "--explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable"
linux_nightly_main_arguments_override: "--explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable"
```

Stable compilers fail on warnings; snapshots omit warnings-as-errors to expose upcoming
compatibility without turning every new warning into a failure. Keep snapshot failures visible:
no `|| true`, fake successes, or blanket `continue-on-error`. Recheck upstream inputs and enabled
versions when raising the tools floor or adopting a newly released compiler.

The PR static SDK job calls `apple/swift-nio/.github/workflows/static_sdk.yml@main`
**without input overrides**. Its defaults build `x86_64-swift-linux-musl` with the latest
released SDK and Swift main development SDK. It cross-compiles; it does not execute tests.
There is no ARM64 or next-release static SDK matrix in this profile. Linux success does not
establish Apple-platform compatibility.

## Soundness and documentation

Use `swiftlang/github-workflows/.github/workflows/soundness.yml@0.0.15` on PRs, with
`api_breakage_check_enabled: false`, `license_header_check_enabled: true`, and explicit
`docs_check_targets` for public targets. No separate API-diff job may re-enable the disabled gate.
SemVer labels still record API impact and reviewers assess compatibility.

Retain upstream format, license, DocC warnings-as-errors/analyze, shellcheck, yamllint,
broken-symlink, unacceptable-language, and applicable Python lint defaults. Do not disable a
check to make CI green. The docs script adds the DocC plugin only in its disposable checkout;
a permanent DocC package dependency is unnecessary. Generated contracts are still documented;
if analysis produces unavoidable generator warnings, record the exact scoped exception.
For compiler warnings in released generated code, keep warnings-as-errors and downgrade only
the demonstrated diagnostic group with `-Xswiftc -Wwarning -Xswiftc <Group>` on supported
stable toolchains. Verify the group exists in each toolchain receiving the flag, record the generator/version and
removal condition, and fix owned-source warnings. Do not use blanket suppression or unsafe
manifest flags that prevent downstream consumption.

## Formatting and headers

[The sample formatter](../assets/sample.swift-format) is the starting point for a library's
`.swift-format`, and preferably a deployable service's too: four-space indentation, 400-column
lines, ordered imports, and its rule set. A repository without a formatter copies it as-is; a
repository whose `AGENTS.md` records its own formatter keeps it and never mass-reformats to the
sample. Public documentation remains required even though the formatter does not enforce documentation on every declaration.
Format and strictly lint all tracked Swift, including manifests and CI consumers, with the CI
formatter toolchain (currently 6.3, `format_check_container_image: swift:6.3-noble`). Generated build output is not tracked or hand-formatted.

Enable compact license-header checking and preserve the repository's license/owner. An MIT
package uses its recorded owner:

```swift
// Copyright (c) 2026 <owner>
// SPDX-License-Identifier: MIT
// See LICENSE for license information.
```

A proprietary project uses its recorded owner and `SPDX-License-Identifier: LicenseRef-Proprietary`,
with the corresponding proprietary `LICENSE`; adopting CI never relicenses a package.
`.license_header_template` uses `@@` instead of `//` and `YEARS` instead of the year. Shell headers
use `##` immediately after `#!/bin/bash`; protobuf sources use `//` too.
Keep `// swift-tools-version:` first in every manifest, followed by the compact header.
`.licenseignore` excludes `Package.swift` (the upstream checker requires the header at line one)
and `LICENSE` (extensionless text); add only specific consumer manifests or unsupported fixture
file formats with a documented reason. Do not ignore all Sources, Tests, or generated-code inputs.

## Dependency resolution and workflow references

**Never track `Package.resolved` in a library**, including nested consumer/Xcode copies. Ignore
it by name, remove any tracked copies, and resolve released remote manifest requirements in
fresh CI checkouts. Do not use `--disable-automatic-resolution`, `--force-resolved-versions`, or
other locked-build flags without a lockfile. A local-path dependency is appropriate only in a
CI consumer fixture that exercises this checkout. Applications and deployables retain validated
lockfiles; their pipeline is separate.

Shared SwiftNIO workflows, the SemVer action, and Foundation consumer checks follow `@main`.
Soundness uses its release tag; directly used standard Actions use major-version tags (currently
`actions/checkout@v7`, with `persist-credentials: false`). This overrides the service SHA-pin
rule. Moving refs include upstream changes and are not immutable; inspect current inputs.
Dependabot checks `github-actions` weekly at `/`, targets main, and labels update PRs `semver/none`.

Every PR has exactly one impact label: `⚠️ semver/major`, `🆕 semver/minor`, `🔨 semver/patch`,
or `semver/none`. The label workflow grants `pull-requests: read` beside `contents: read`; a
private repository's default token cannot read the labels without it. Preserve the repository's release mechanism: a manual label-based Auto Release
may reuse the shared workflow at `@main`; a contract/SDK package can keep bare version tags.
Adding CI does not publish a release. A bare-tag exception changes release machinery, not the
SemVer PR gate.

## Capability exceptions

**Foundation linking.** Use `vapor/ci/.github/workflows/check-foundation-linking.yml@main` twice,
with `swift_image: swift:6.3-noble` and `swift:6.4-noble`, on PRs and main. It builds downstream
release consumers and rejects full Foundation, Internationalization, and ICU linkage. Static SDK
success does not prove this. A PostgresNIO or Vapor 4 product may require full Foundation upstream:
list only those products in `excluded_products`, leaving unaffected products checked. If every
product requires it, omit the gate and record why, which trait/product configurations it affects,
and retained release/static coverage. Use FoundationEssentials in owned code where available;
do not wrap standard types just to evade the checker.

**PostgreSQL integration.** A package with actual database I/O tests replaces generic unit tests
with a reusable custom Linux matrix on the same four toolchains and test flags. See
[the PostgreSQL test template](../assets/library-postgres-tests.yml). Use a PostgreSQL 18 service
(or the project's documented supported version), with `pg_isready -h 127.0.0.1` health checking:
a Unix socket may report healthy during temporary initialization before TCP is ready. Connect
tests to the service hostname and matching credentials/database; run `swift test --parallel`.
A missing/unhealthy database fails, never skips the tests or substitutes mocks. Keep soundness,
release, and PR-only static builds. Merely depending on PostgresNIO does not require a database
service when tests exercise only settings/mocks.

**Generated/no-test packages.** If there are no meaningful runtime tests, replace `swift test`
with a four-toolchain `swift build` matrix using the same stable/snapshot flags, plus an actual
downstream consumer that imports generated public messages/client protocols or exported SDK APIs.
Use [the build template](../assets/library-builds.yml), adapted to those products/configurations.
Do not create placeholder test targets or `#expect(true)` tests. Keep DocC, release and static
builds. Run code generators on the host during cross-compilation; do not target the generator
itself at the destination SDK or commit generated output to bypass plugin failures.

**Traits.** Build default and disabled defaults, plus distinct supported enabled combinations.
A second configuration that is identical to the default adds no coverage. Consumer checks must
use the intended traits; state exactly what the default-only shared release/static workflows
cover. Add a scoped trait build where promised static support would otherwise be untested.
A default URLSession transport does not prove a custom-transport build. A generated full
Foundation import can affect both configurations; do not claim disabling a transport makes it
Foundation-free without a consumer linkage check.

Add examples, C++ interoperability, or other SDKs only for capabilities the package supplies.
Record each exception in the repository's `AGENTS.md`: the dependency or capability that forces
it, the version it was observed at, the products and configurations it affects, and the actual
replacement coverage; revisit it when that dependency's resolved version changes.

## Private organization libraries

A private library in an organization (its core package, protos, or SDK) keeps every gate above,
but private repositories pay for hosted minutes and the shared reusable workflows cannot fetch
private dependencies. The pattern:

- One local reusable `.github/workflows/ci.yml`, called from `pull_request.yml` (with an input
  enabling soundness, DocC, and static SDK jobs) and from `main.yml`. Jobs run on the
  organization's self-hosted runner (`runs-on: [self-hosted, Linux, X64]`) with each toolchain
  as the job's `container:`: the same four toolchains, test overrides, and release builds as the
  compiler matrix. The runner's service account needs Docker; keep self-hosted runners off
  public repositories.
- Soundness and DocC run the upstream scripts from a checkout of `swiftlang/github-workflows`
  pinned to the release's commit SHA; Foundation linking inlines the `vapor/ci` check with the
  same excluded products; the label workflow keeps the shared checker and `pull-requests: read`.
- Private dependencies resolve with a read-only credential scoped to the organization's
  repositories (a GitHub App installation token or a fine-grained token with `contents: read`),
  stored as a secret and written to `~/.netrc` inside the job. It never enters a manifest, a
  remote URL, or the checkout's persisted credentials, and a missing secret fails the job:

  ```yaml
  - name: Authenticate private dependencies
    env:
      PACKAGES_TOKEN: ${{ secrets.PACKAGES_READ_TOKEN }}
    run: |
      : "${PACKAGES_TOKEN:?set the PACKAGES_READ_TOKEN secret}"
      umask 077
      printf 'machine github.com\nlogin x-access-token\npassword %s\n' "$PACKAGES_TOKEN" > ~/.netrc
  ```

- No Swift Package Index: no `.spi.yml` and no documentation badge; DocC builds only in CI, and
  consumers resolve tags with their own GitHub credentials. Record the runner, the credential,
  and these replacements in `AGENTS.md`.

## Validation and completion

- Validate effective triggers, matrices, flags, reusable-workflow inputs, and workflow syntax;
  run actionlint, strict yamllint, shellcheck where applicable, formatter and license checks.
- Build/test supported configurations locally where available; prove database behavior against
  the real provider when changing it. Verify downstream contracts rather than counting tests.
- Check `git ls-files` contains no library resolved files and broad ignores do not conceal owned code.
- Ensure all intended public targets are documented and label/dependency policies are configured.
- Review branch-protection requirements separately; do not claim workflow edits configure them.
- Report local results and remaining GitHub/Linux/snapshot validation accurately. Do not poll CI
  indefinitely; configuration work can be reviewed without starting CI monitoring.
