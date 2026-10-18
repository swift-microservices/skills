# Library CI

The standard CI for every reusable Swift library used in server development: the organization's
packages, a project's core, contract, and SDK packages, and adapters. Every library gets the same
shape; a repository that differs records each difference as an exception in its `AGENTS.md`
(see [Recording the profile](#recording-the-profile)). Executable delivery lives in
[services-ci.md](services-ci.md) and [delivery.md](delivery.md).

## Contents

- [The standard shape](#the-standard-shape)
- [Toolchains](#toolchains)
- [Soundness and documentation](#soundness-and-documentation)
- [Formatting and headers](#formatting-and-headers)
- [Dependencies, references, and releases](#dependencies-references-and-releases)
- [Exceptions](#exceptions)
- [Recording the profile](#recording-the-profile)
- [Validation and completion](#validation-and-completion)

## The standard shape

| Job | Pull requests | Pushes to main |
| --- | --- | --- |
| Soundness: format, license headers, DocC, YAML, shell, language, symlinks | Yes | No |
| Tests: `swift test -c release` on every supported toolchain | Yes | Yes |
| Static Linux SDK builds | Yes | No |
| Foundation linking, once, on the floor toolchain | Yes | Yes |
| Exactly one SemVer label | Yes, also on label changes | No |

Releases are cut by hand with Auto Release. There are no scheduled runs, API-breakage job,
macOS or Windows jobs, consumer fixture packages, images, or deployments.

Copy the templates, replacing the DocC target names:

- [library-pull-request.yml](../assets/library-pull-request.yml) → `.github/workflows/pull_request.yml`
- [library-main.yml](../assets/library-main.yml) → `.github/workflows/main.yml`
- [library-pr-label.yml](../assets/library-pr-label.yml) → `.github/workflows/pull_request_label.yml`
- [library-auto-release.yml](../assets/library-auto-release.yml) → `.github/workflows/auto-release.yml`
- [library-dependabot.yml](../assets/library-dependabot.yml) → `.github/dependabot.yml`

Every job reuses an upstream workflow: swiftlang/github-workflows for soundness and tests,
vapor/ci for Foundation linking, swift-nio's SemVer label action, and swift-temporal-sdk's Auto
Release. A repository adds a local workflow only for what none of them can do (a database
service, below). Keep jobs independent: no `needs:` between unrelated checks.

## Toolchains

The templates use **Swift 6.3 as the floor**, the oldest toolchain a library supports. The tests
job takes swiftlang's default version list (released versions and the next and main snapshots)
and excludes the versions below the floor with `linux_exclude_swift_versions`, so a newly
released toolchain arrives when Dependabot bumps the swiftlang pin, without editing the list.

Tests run in release mode: `swift test -c release` builds every target optimized and runs the
tests in one job per toolchain, so there is no separate release-build job. Stable toolchains use
`swift_flags` with warnings as errors; snapshots use `swift_nightly_flags`, the same flags
without `-warnings-as-errors`, so a new warning in an unreleased compiler stays visible without
failing the run. Keep snapshot failures visible: no `continue-on-error` or `|| true`.

Raise the floor in one change per repository, and in the services and the ci repository with it:

```
Raise the Swift floor:
- [ ] Libraries: add the old floor to linux_exclude_swift_versions; move format_check_container_image and the Foundation-linking swift_image to the new floor; update a narrowed matrix's linux_swift_versions and a database tests.yml matrix; raise the tools version
- [ ] Services: tests' linux_swift_versions, the soundness format image, and the Containerfile's build stage, together (services-ci.md)
- [ ] The ci repository: tests.yml's default linux_swift_versions, released, then each caller's pin bumped
- [ ] Each AGENTS.md that names the toolchain
```

## Soundness and documentation

Call swiftlang's `soundness.yml` on pull requests with `api_breakage_check_enabled: false`,
`license_header_check_enabled: true`, the floor's `format_check_container_image`, and explicit
`docs_check_targets` for every public target. Keep the remaining upstream checks at their
defaults; turning one off to make CI green is not an exception. SemVer labels record API
impact in place of the breakage job.

Generated code is documented too. For a compiler warning in released generated code, keep
warnings as errors and downgrade only the demonstrated diagnostic group with
`-Xswiftc -Wwarning -Xswiftc <Group>` on the toolchains that have it; record the generator
version and when to remove it. Fix warnings in owned code.

## Formatting and headers

[The sample formatter](../assets/sample.swift-format) is the starting point for a library's
`.swift-format`: four-space indentation, 400-column lines, ordered imports, and its rule set. A
repository without a formatter copies it; one whose `AGENTS.md` records its own keeps it and is
never mass-reformatted. Format and strictly lint every tracked Swift file, manifests included.

Enable the compact license header and preserve the repository's license and owner. An MIT
package uses its recorded owner:

```swift
// Copyright (c) 2026 <owner>
// SPDX-License-Identifier: MIT
// See LICENSE for license information.
```

A proprietary project uses `SPDX-License-Identifier: LicenseRef-Proprietary` with its
proprietary `LICENSE`; adding CI never relicenses a package. `.license_header_template` uses `@@`
instead of `//` and `YEARS` instead of the year. Keep `// swift-tools-version:` first in every
manifest, followed by the header. `.licenseignore` lists `Package.swift` (the checker requires
the header on line one) and `LICENSE`, and nothing broader.

## Dependencies, references, and releases

**A library never tracks `Package.resolved`.** Ignore it by name and resolve released
requirements in fresh CI checkouts, without `--disable-automatic-resolution`.

Pin every reusable workflow and action to its latest release's full commit, with the release in
a comment (`@<commit>  # 0.0.16`); an upstream without releases is pinned to a `main` commit
(`# main`). Dependabot checks `github-actions` weekly and labels its pull requests
`semver/none`, so pins move by reviewed pull requests.

Every pull request carries exactly one label: `⚠️ semver/major`, `🆕 semver/minor`,
`🔨 semver/patch`, or `semver/none`. The label workflow grants `pull-requests: read`, which a
private repository's token needs to read labels. Auto Release, run by hand on main, tags the next
version from the merged labels and needs one existing release to start from: cut the first by
hand. A major release is cut by hand.

## Exceptions

Each is a change to the standard shape that a repository makes only when the condition holds,
and records.

**A product links full Foundation.** vapor/ci's check builds a downstream release consumer of
every library product and fails on full Foundation, Internationalization, or ICU. When a
dependency forces full Foundation on some products (PostgresNIO, Vapor 4), list those in
`excluded_products` and keep checking the rest. When it affects every library product, the check
has nothing left to build and fails, so omit the job and record why. Owned code still uses
FoundationEssentials where it can.

**Tests need a database.** swiftlang's workflow cannot attach a service container. Copy
[library-postgres-tests.yml](../assets/library-postgres-tests.yml) to `.github/workflows/tests.yml`
(the same toolchains and flags, beside PostgreSQL) and call it from both workflows in place of
the tests job. Its matrix is written out, so keep it equal to the pinned swiftlang release's
default versions above the floor when Dependabot bumps that pin. On pull requests, keep the static SDK builds with swiftlang's workflow and its
tests turned off:

```yaml
  tests:
    name: Tests
    uses: ./.github/workflows/tests.yml

  static-sdk:
    name: Static Linux Swift SDK
    uses: swiftlang/github-workflows/.github/workflows/swift_package_test.yml@<commit>  # <release>
    with:
      enable_linux_checks: false
      enable_linux_static_sdk_build: true
      swift_flags: "<the tests job's swift_flags>"
      swift_nightly_flags: "<the tests job's swift_nightly_flags>"
      enable_windows_checks: false
```

Health-check with `pg_isready -h 127.0.0.1` (a Unix socket answers before TCP does). A missing
database fails the tests; it never skips them. Depending on PostgresNIO without database tests
needs no service.

**No tests.** `swift test` fails when a package has no test targets, so a package without
meaningful runtime tests (generated contracts) sets `linux_build_command: swift build -c release`.
Never add placeholder tests.

**Debug-only code.** Release mode skips `assert` and `#if DEBUG` code. A package that has either
adds a second tests job with `linux_build_command: swift test`.

**Traits.** CI builds the default traits. Record the other supported trait configurations, and
build them locally when changing the code they gate.

**A private repository.** Its Actions minutes are billed, so it may narrow the tests job to the
floor toolchain and the architecture its consumers deploy on (`linux_swift_versions: '["6.3"]'`,
`linux_host_archs: '["aarch64"]'`), drop the static SDK builds, and turn off soundness checks for
file types it does not contain (`shell_check_enabled`, `python_lint_check_enabled`). A private
repository has no Swift Package Index page or documentation badge.

**Private dependencies.** swiftlang's workflow takes no secrets, so a library that depends on
another private repository calls `swift-microservices/ci/.github/workflows/tests.yml` instead,
with the same inputs and `secrets: PACKAGES_TOKEN: ${{ secrets.PACKAGES_TOKEN }}`: a
fine-grained token with Contents read-only on just those repositories.

**A soundness input.** An input changed for a demonstrated reason, such as a docs check that
exceeds its timeout on the floor toolchain and runs on a newer image.

## Recording the profile

Every repository's `AGENTS.md` has a `## CI` section: which standard it follows, then one bullet
per exception with what differs, the dependency or condition that forces it (with its version),
what still covers it, and when to revisit. A repository with no exceptions says so. A difference
without a recorded exception is drift: restore the standard shape.

```markdown
## CI

The standard library CI from the swift-microservices delivery skill. Exceptions:

- No Foundation-linking job: the one product depends on PostgresNIO 1.33, which links full
  Foundation. Owned code uses FoundationEssentials. Revisit when PostgresNIO drops it.
```

## Validation and completion

- Run actionlint and strict yamllint on the workflows, and the formatter and license-header
  checks; confirm each reusable workflow's inputs against its pinned release.
- Build and test locally where possible; prove database behavior against a real database.
- Confirm `git ls-files` lists no `Package.resolved`.
- Report what ran locally and what only GitHub can run. Workflow changes do not configure branch
  protection; check that separately.
