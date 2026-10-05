# The library repository

## Contents

- Layout
- README
- AGENTS.md
- DocC and the Swift Package Index
- Headers, formatting, and CI

## Layout

```text
swift-<concept>[-<technology>]/
  Package.swift
  README.md
  AGENTS.md
  LICENSE
  .gitignore                     # .build, .swiftpm, Package.resolved, Xcode state
  .swift-format                  # the library formatter asset, byte-for-byte
  .license_header_template
  .licenseignore                 # Package.swift and LICENSE only
  .spi.yml
  .github/                       # the library CI profile's workflows, Dependabot, release notes
  scripts/test.sh                # only a driver that needs a real provider
  Sources/<Module>/
    <Type>.swift                 # one public declaration per file, named for it
    Documentation.docc/
      <Module>.md
      Articles/<Concept>.md
  Tests/<Module>Tests/
```

Group sources by concept only when a module holds more than a handful of files; never `Utilities`, `Helpers`, or `Extensions` buckets. An extension on another module's type lives in `<Type>+<Concept>.swift`.

## README

The README is what a consumer reads before adding the dependency. In order:

1. The package name, the documentation badge, and one sentence saying what it provides.
2. A paragraph on what it depends on and what it deliberately leaves to others.
3. The install snippets, at the latest release's floor:

   ```swift
   .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.2.0"),
   ```

   ```swift
   .product(name: "Persistence", package: "swift-persistence"),
   ```

4. The concept, with code that compiles against the current API, using a neutral example payload (`AppToken`, `CreatePostUseCase`), never an organization's types.
5. The family: a table of the sibling packages (drivers, bindings) and what each adds.
6. Requirements: Swift 6.3, macOS 15 or Linux, the minimum versions of the upstreams that matter.
7. Development (`swift test`, or `scripts/test.sh` for a driver; `swift-format lint --strict --recursive Sources Tests`), Contributing, License.

Keep the snippet and the requirements in step with each release; a stale floor is the most common README defect.

## AGENTS.md

Every library carries an `AGENTS.md`, the repository profile an agent reads before any change. Its sections:

- **What this package is**: its products, what each holds, what it depends on and why that set is the whole set, and the test that states the shape consumers rely on.
- **What does not belong here**: the concepts a contributor will be tempted to add, and where each lives instead (another package, the organization layer, a composition root).
- **Application standard**, where the package touches security: the rules it assumes of its consumers, stated once (users are proved by JWTs, processes by transport mTLS; bindings apply to `<Entity>Service` descriptors only, never internal ones; authorization lives in the owning use case).
- **Swift**: Swift 6.3 and strict concurrency, swift-testing, documentation on every public declaration and a warning-free DocC catalog, the formatter and its lint command, the header format.
- **Releases**: the SemVer labels, the Auto Release workflow, "consumers pin by tag, never by branch or path".
- **Library CI profile**: the gates the repository runs and every capability exception with its reason and replacement coverage (a PostgresNIO or Vapor 4 full-Foundation requirement, a real-database test matrix, a generated package's build-only matrix), as the [library CI profile](../../delivering-swift-services/references/library-ci.md) requires.

An application's or organization layer's `AGENTS.md` adds a **Skills** table routing tasks to these skills, and its **conventions**: the shape, transport, identity, database, and delivery decisions the skills leave as project choices. Keep the profile true: a rule the code does not follow is a defect in one of them.

## DocC and the Swift Package Index

Each public target has `Sources/<Module>/Documentation.docc/<Module>.md`, a landing page whose topics group every public symbol, and articles for the concepts the symbol comments cannot hold. `.spi.yml` lists the documented targets:

```yaml
version: 1
builder:
  configs:
    - documentation_targets: [Persistence]
```

A README that links a documentation badge needs both the catalog and `.spi.yml`; the soundness workflow's `docs_check_targets` names the same targets, and the catalog builds without warnings. The DocC plugin is added only in the docs check's disposable checkout, never as a permanent package dependency.

## Headers, formatting, and CI

Every tracked Swift file, script, and workflow carries the compact license header matched by `.license_header_template`; `Package.swift` keeps the tools-version line first, then the header. Copy the library formatter asset byte-for-byte to `.swift-format` and lint all tracked Swift, manifests included. The workflows, the gates, Dependabot, the release workflow, and every exception are the delivering skill's [library CI profile](../../delivering-swift-services/references/library-ci.md); apply it as written and record exceptions in `AGENTS.md`.
