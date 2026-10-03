# Reusable library CI

Use this profile for packages consumed by other packages: shared Core, contracts, SDKs, and
standalone libraries. Repository `AGENTS.md` and explicit user decisions override defaults.
Service deployment branches, image publishing, and locked service builds live in
[delivery.md](delivery.md).

## Shared design

Follow the design used by [Swift Temporal SDK](https://github.com/apple/swift-temporal-sdk/blob/main/.github/workflows/pull_request.yml)
and [Swift Configuration](https://github.com/apple/swift-configuration/blob/main/.github/workflows/pull_request.yml):
Swift.org soundness checks, SwiftNIO test/build workflows, and focused package-specific checks.
These repositories select different optional jobs; copying every job is not the goal.

- Run PR checks and compatibility builds on pushes to main. Schedule a weekly run on main
  to detect dependency and compiler changes; twice-daily checks are an optional Apple cadence.
- Never commit `Package.resolved` in libraries. Resolve released dependencies from manifest
  requirements in fresh CI checkouts; do not apply a service's `--disable-automatic-resolution`
  command to an absent library lockfile. Keep application/service lockfiles tracked.
- Test every supported stable compiler from the minimum tools version through the current
  stable release. Enable next-release and main snapshots for forward compatibility. Require
  stable checks for merging; snapshot failures remain visible and advisory unless the
  repository explicitly makes them required. Do not hide failures with blanket success fallbacks.
- Build optimized release products as well as running debug tests. Packages without meaningful
  runtime tests still need build and consumer/contract validation; do not add placeholder tests.
- Run formatting, API compatibility, documentation, and applicable script/YAML checks through
  `swiftlang/github-workflows/soundness.yml`. Its documentation script can add the DocC plugin
  in the disposable checkout, so no permanent manifest dependency is required.
- Use `apple/swift-nio` workflows for generic test/build matrices. Swift.org's
  `swift_package_test.yml` is also suitable, including for additional SDK checks.
  Neither choice changes SwiftPM's test engine or requires a source dependency on SwiftNIO.

## Coverage and exceptions

Declare supported compilers and CI platforms in `AGENTS.md`. The swift-microservices profile
uses Linux-only CI by user choice. Apple-platform compatibility is verified separately when
needed; a successful Linux job does not establish macOS/iOS compatibility. If macOS CI is
requested later, use runners the organization can access: SwiftNIO's current macOS workflow
explicitly skips repositories outside `apple` and uses Apple's self-hosted pool.

Add checks only for capabilities the library supplies or promises:

- A static Linux SDK build when consumers use musl/static deployment. Document unsupported
  products or traits and the exact coverage rather than silently claiming the entire package.
- A downstream consumer/linkage check when avoiding full Foundation is a requirement. Static
  SDK success proves build compatibility, not the absence of Foundation code. Retain the
  [Foundation-linking gate](delivery.md#foundation-linking) where applicable.
- Real database/provider integration when behavior depends on that system. A database driver
  can replace the generic unit-test workflow with a matching compiler matrix and a healthy
  service container; preserve release/static build checks independently.
- Default, disabled, and relevant enabled trait configurations when the package exposes traits.
  Examples, C++ interoperability, benchmarks, and additional SDKs need an actual supported use.

Record each exclusion, its reason, and any replacement coverage in the repository profile.
For swift-microservices, source author headers replace license blocks, while the license file
remains authoritative. Full Foundation through Vapor 4 or PostgresNIO is an upstream dependency
exception; keep our code on FoundationEssentials where available.

## Formatting profile

For new swift-microservices libraries, copy [the library formatter](../assets/library.swift-format)
to `.swift-format`. It is the exact file from Swift Temporal SDK commit
`508797b5468dbc532f77c317bf9df0cb3231f5c1`: four-space indentation, 150-column lines,
and ordered imports. Preserve an existing repository formatter unless changing it is requested.
Public API documentation remains a repository requirement even though this config does not
enforce documentation on every public declaration.

Format and strictly lint all tracked Swift files, including manifests, using the same formatter
toolchain as the CI formatting job. The service profile's 400-column default is separate.

## Workflow dependencies and releases

Pin actions and reusable workflows to reviewed commit SHAs with a release tag or branch/date
comment. A reviewed main commit is appropriate when needed inputs precede an upstream release.
Inspect internal calls and downloaded scripts: a pinned SwiftNIO caller can still execute
nested workflows and scripts from upstream main. Do not describe it as fully immutable.
Dependabot updates workflow references on main; a library has no deployment develop branch
unless its own profile explicitly defines one.

Preserve the repository's SemVer-label and release automation policy. Contract packages may
use bare tags; library CI does not impose a new release mechanism on an existing repository.

## Completion gates

- Every declared stable compiler is covered and the minimum follows the manifest.
- Applicable tests, release/static builds, soundness, and provider/consumer checks execute.
- Exclusions and advisory snapshot policy are explicit; required check names match branch protection.
- Formatting matches the selected profile and all tracked Swift files pass strict lint.
- Library resolved files remain ignored and generated lockfiles are never staged.
- Validate workflow syntax and reusable-workflow inputs; report which checks ran locally and
  which depend on GitHub runners, snapshots, or external integration systems.
