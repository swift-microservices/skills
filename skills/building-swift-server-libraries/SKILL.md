---
name: building-swift-server-libraries
description: Builds or changes a reusable Swift server library package the swift-microservices way, such as swift-persistence, a swift-persistence-<store> driver, a swift-authentication-<technology> binding, or an organization's <project>-core. One concept per package cut by its dependency set, one product, low version floors, tagged SemVer releases with labels, a small documented public API with caller-isolated scoped callbacks and ServiceContext keys, no logging bootstrap or environment reading, swift-testing with isolation contract tests and real-provider driver tests, README, AGENTS.md profile, DocC, and the library CI profile. Use when creating a Swift library package for server use, adding public API, a driver, a binding, or a product to one, raising its dependency floors, preparing a release, or editing a library's Package.swift, Sources, Tests, README, or AGENTS.md.
---

# Building Swift server libraries

One way to build a reusable package that Swift servers depend on by tag: the [swift-microservices](https://github.com/swift-microservices) packages themselves, a new driver or binding beside them, and an organization's `<project>-core` and `<project>-protos`. A library is not a service: it has no executable, no database of its own, no composition root, and no deployment. Services and monoliths are the building-swift-services skill's; the Swift inside every package follows the writing-swift-server-code skill.

Read applicable `AGENTS.md` files first: their repository profile and recorded exceptions override these general conventions. Preserve unrelated established code, public API, and history.

Rules in this skill are conventions the packages and their consumers depend on; keep them unless the user changes the vocabulary.

## Load the references

| Task | Read |
| --- | --- |
| Every task | [package.md](references/package.md) — the family, one concept per dependency set, naming, the manifest, floors, platforms, versions and releases |
| Any public declaration | [api.md](references/api.md) — access and imports, protocol-shaped surfaces, errors, scoped callbacks and isolation, `ServiceContext` keys, logging, configuration, lifecycle, documentation |
| Tests | [testing.md](references/testing.md) — what a library test proves, isolation contract tests, bindings, real providers |
| README, `AGENTS.md`, DocC, `.spi.yml`, headers, formatter | [repository.md](references/repository.md) |
| `<project>-core` or `<project>-protos` | [organization-layer.md](references/organization-layer.md) |
| Swift settings, Foundation, style | the writing-swift-server-code skill's [swift-settings.md](../writing-swift-server-code/references/swift-settings.md), [foundation.md](../writing-swift-server-code/references/foundation.md), and [style.md](../writing-swift-server-code/references/style.md) |
| CI workflows, gates, and exceptions | the delivering skill's [library-ci.md](../delivering-swift-services/references/library-ci.md) |

## Principles

1. **A package is one concept and one dependency set.** A consumer that imports it acquires exactly the technology its name promises. A type that needs a new dependency belongs in another package.
2. **Generic machinery knows nothing of an organization.** Claims, roles, setting names, contracts, and authorization belong to the organization layer and the owning services.
3. **The public API is a contract.** Small, `Sendable`, documented on every declaration, proven by a test per guarantee, and changed only with the SemVer label the change needs.
4. **Preserve the caller.** A scoped callback runs on the caller's isolation, an error reaches the caller unchanged, and a library never takes over logging, configuration, or lifecycle from the application that composes it.
5. **The consumer chooses versions.** A library's floor is the oldest release it needs; the application resolves newer ones and commits the lockfile. Tags never move.

## Rules

### Package

1. Name the repository `swift-<concept>` for an abstraction and `swift-<concept>-<technology>` for its driver or binding; the product and module are `<Concept>` or `<Concept><Technology>`, with no organization prefix.
2. Expose one library product unless a second dependency set must be avoidable by consumers. A driver or binding depends on its abstraction by tagged URL, never `.package(path:)` or a branch.
3. Use Swift tools 6.3, the compact license header after the tools-version line, one shared settings array with the four upcoming features attached to every target and test target, `swiftLanguageModes: [.v6]`, and `.macOS(.v15)`; a package meant for apps too declares their platforms. No unsafe flags, `@preconcurrency`, or default MainActor isolation.
4. Set each `from:` to the oldest release the library relies on and raise it deliberately, saying why; never add a ceiling. Declare traits explicitly where defaults pull in full Foundation, and record an unavoidable upstream full-Foundation product as a profile exception.
5. Never commit `Package.resolved`.
6. Label every pull request with exactly one SemVer impact. Before 1.0.0, a breaking change is `🆕 semver/minor` and a compatible addition, a floor raise, or a fix to doc comments or the DocC catalog `🔨 semver/patch`; README, `AGENTS.md`, tests, CI, and formatting are `semver/none`. Release with the repository's recorded mechanism, a label-based Auto Release workflow or bare version tags cut by hand; never move a published tag.

### API

7. `public` only for what consumers use; `public import` exactly where an imported type appears in public API. Every public type and protocol is `Sendable` where meaningful; mutable shared state lives in an actor or behind a `Mutex`.
8. Shape substitution points as protocols with primary associated types, and make concrete types generic over the consumer's own types. A requirement returns what it promises or throws; it never returns an optional to mean "declined".
9. Keep a scoped callback plain, nonescaping, and caller-isolated, `(Scope) async throws -> T` with `T: Sendable`, with neither `@Sendable` nor `@concurrent`, in the requirement, every implementation, and every double; forward with `isolation: #isolation`. Match a framework's `@concurrent` continuation requirement exactly where one is imposed.
10. Carry task-scoped values in a `ServiceContextKey` with a stable `nameOverride` and a typed accessor, never a `@TaskLocal` of the library's own. A binding sets it with `ServiceContext.withValue` and keeps the framework's own state in step.
11. Let errors reach the caller unchanged; translate only at a transport boundary, to the framework's unauthenticated error with a stable message.
12. Take a `Logger` as the last initializer parameter, with no default; only a trailing operation closure follows it. Never bootstrap logging, read the environment, construct a configuration provider, open fixed paths, or own global lifecycle. A convenience `init(config:)` reads relative keys and delegates to the typed initializer; a long-lived runnable conforms to `Service`.
13. Document every public declaration with a one-line summary, and keep a DocC catalog that builds without warnings, with articles for contracts a signature cannot state.

### Tests and repository

14. Test on swift-testing in `<Module>Tests` with plain imports, one test per public guarantee, doubles inside the test target, and framework in-memory harnesses for bindings.
15. A package that owns a caller-isolated callback API tests it from a custom actor and from `@MainActor`, suspending inside the closure and checking isolation on both sides, plus thrown-error propagation and cancellation.
16. A driver proves commit, rollback, and its settings against the real provider, configured from `POSTGRES_*` environment variables with a `scripts/test.sh` that starts an ephemeral server; CI provides the database and fails without it.
17. Keep README, `AGENTS.md`, DocC, and `.spi.yml` true to the released API: install snippets at the current floor, the family table complete, every profile exception stated with its replacement coverage.
18. Apply the delivering skill's library CI profile as written; start `.swift-format` from its sample formatter unless the profile records another, and lint all tracked Swift, manifests included.

## Workflow

Copy the checklist that matches the task and check items off as you go.

```
Create a library:
- [ ] 1. Concept and dependency set: confirm it is generic, not already a package, and needs exactly the dependencies its name promises
- [ ] 2. Manifest: name, header, settings array on every target, platforms, one product, floors, explicit traits
- [ ] 3. API: protocols with primary associated types, Sendable types, caller-isolated callbacks, ServiceContext keys, Logger last, documentation on every declaration
- [ ] 4. Tests: one per guarantee; isolation contract tests for scoped callbacks; real-provider tests and scripts/test.sh for a driver
- [ ] 5. Repository: README, AGENTS.md profile, DocC catalog, .spi.yml, .swift-format, header template, .licenseignore, .gitignore with Package.resolved
- [ ] 6. CI from the library profile; then swift build, swift test (or scripts/test.sh), and swift-format lint --strict
- [ ] 7. Release: one SemVer label, the repository's release mechanism (Auto Release or a hand-cut tag), then raise consumers' floors
```

```
Change a library:
- [ ] 1. Classify the change: addition, behavior change, removal, floor raise, or documentation; pick the SemVer label it needs
- [ ] 2. Change the test that states the guarantee first, then the API and its documentation
- [ ] 3. Update README snippets, the family table, DocC articles, and AGENTS.md where they describe what changed
- [ ] 4. swift build, swift test, formatter lint; note what needs Linux, a real provider, or CI
```

## Completion gates

Do not call work complete until every applicable gate passes.

- The package builds and its tests pass with `swift build` and `swift test` (a driver against a real provider), with every owned target on the shared settings and no diagnostic silenced.
- The manifest declares only used products and packages, by tagged URL, with floors the library needs and explicit traits; no `Package.resolved` is tracked.
- Every public declaration is documented, `Sendable` where meaningful, and covered by a test of its guarantee; scoped callbacks are caller-isolated and proven so from an actor and from `@MainActor`.
- No library type bootstraps logging, reads the environment, decides authorization, names an organization's claims, or declares its own task-local.
- README, `AGENTS.md`, DocC, and `.spi.yml` describe the released API; the pull request carries exactly one SemVer label matching the change.

If a gate requires an unresolved API, compatibility, or release decision — removing public API, raising a floor consumers cannot meet, or a major release — stop at the safe boundary and request that decision rather than inventing behavior.
