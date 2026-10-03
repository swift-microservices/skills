# Service CI

The recommended standard CI profile for deployable Swift server applications validates the
configuration that actually ships. Library compiler compatibility belongs to
[library-ci.md](library-ci.md); publishing, deployment, environments and rollback belong to
[delivery.md](delivery.md). A modular monolith, gateway or worker uses this same service profile.
Repository `AGENTS.md` records the deployed toolchain, OS, architecture, executable products,
worker commands and justified style or coverage exceptions. Explicit user scope takes precedence.

## Contents

- Events and gates
- Workflow layout and references
- Source quality and headers
- Locked dependency resolution
- Tests and capability coverage
- Static SDK compatibility
- Release image and Foundation
- Publishing and deployment ordering
- Dependency updates and completion

## Events and gates

| Event | Required behavior |
| --- | --- |
| PR opened/reopened/synchronize, any target branch | Source quality, workflow lint, locked existing tests, supported static SDK build, final release-image build and smoke check; no publication/deployment |
| Push to develop | Same source/tests/static checks, then build and smoke-check the release image, publish it, and trigger staging deployment |
| Push to main | Same checks and image validation/publication, then production deployment where configured |
| Dependabot | Weekly Swift and Actions update PRs against develop; normal PR checks apply |

No scheduled CI, snapshot toolchains, macOS/Windows compatibility matrix, API-breaking gate,
SemVer label gate or automatic service release. A service's source commit is its version.
Registry cleanup is separate operational housekeeping; its existing schedule is not a scheduled
test sweep. Keep its retention and deployment policy in delivery.md.

Use one released toolchain, one Linux distribution and the native deployment architecture,
matching the Containerfile. The templates use Swift 6.3 / Ubuntu Noble / ARM64. Update tests,
static SDK, formatter and images together when the repository changes its deployed toolchain;
do not silently switch an application to the latest library matrix.

## Workflow layout and references

Copy the service assets into these destinations and fill in the product, registry and optional
Containerfile target/worker inputs:

- `service-checks.yml` → `.github/workflows/checks.yml` (reusable source/tests/static checks).
- `service-image.yml` → `.github/workflows/image.yml` (reusable native image build/validation).
- `service-check-image.sh` → `.github/scripts/check-image.sh`.
- `service-pull-request.yml`, `service-develop.yml`, `service-main.yml` → their corresponding workflows.
- `service-dependabot.yml` → `.github/dependabot.yml`.

Reuse `swiftlang/github-workflows` soundness and package-test workflows pinned to a reviewed
release's commit SHA. Their configurable platform/toolchain inputs suit a service's one deployed
configuration. Keep direct third-party actions SHA-pinned with the reviewed release as a comment.
Dependabot maintains those references. Upstream workflows may themselves check out moving
branches/actions; a pinned caller alone does not make the entire workflow immutable. Inspect
nested references when changing workflow versions. Libraries keep their separate reference policy.

The actionlint step installs a released binary with a checked SHA-256; update its version and
checksum together. YAML and shell checks are part of soundness. Do not silently ignore failures.
Use stable named required checks in branch protection where repository settings are in scope;
do not assume opening a PR configures protection.

## Source quality and headers

Run strict swift-format on tracked Swift sources, tests and manifests, plus YAML, shell and
workflow checks. Copy `assets/library.swift-format` to `.swift-format` and follow the compact
header conventions in [library-ci.md](library-ci.md#formatting-and-headers), including the
matching template and narrow exclusions. Preserve the actual license and owner; headers do not
relicense it.

An explicit application profile may override formatting and headers. For example, EmberFilm
services retain four spaces, a 400-column `.swift-format`, and varying Xcode author headers.
Do not mass-reformat them to 150 columns or replace their headers while adding CI. Record that
the uniform license-template check is disabled for this style exception; formatter lint remains
required. A uniform compact-header project enables that check and provides its matching template.

Disable API-breakage and public DocC checks for executables. Documentation owned by a reusable
library keeps that library's CI gates. Tests/builds use warnings-as-errors, explicit dependency
import checking and required explicit Sendable conformances on the supported released toolchain.
A proven generated-code compiler exception must stay narrow and documented, as in the library
profile; broad warning suppression is not a solution.

## Locked dependency resolution

A deployable application tracks its validated `Package.resolved`, including dependency-update
PRs. Every test, release build, static SDK build and Containerfile resolve/build must use it.
Use `--disable-automatic-resolution` (also named `--force-resolved-versions`) to reject a stale
manifest/lockfile pair rather than updating the graph in CI. Fetching the locked graph is allowed.
Dependencies use released remote requirements; no local paths or moving branches in shipped
manifests. Library repositories still do not track their resolved files.

Cache layers/build state by manifest, lockfile and toolchain; caching never replaces lockfile
validation. In a Containerfile, copy `Package.*` before source and use:

```dockerfile
RUN swift package --disable-automatic-resolution resolve
RUN swift build --configuration release --disable-automatic-resolution \
    --static-swift-stdlib --explicit-target-dependency-import-check error \
    -Xswiftc -warnings-as-errors -Xswiftc -require-explicit-sendable --product <service>
```

## Tests and capability coverage

Run the existing focused suites on the deployed Linux architecture. Include Core business
behavior, configuration readers, real loopback RPC/HTTP and JWT fixtures where they already
exist. Do not duplicate generic transport failure matrices owned by a shared library.

Temporal services keep their time-skipping, worker-registration and recorded-history replay
coverage. Use the SDK's test-server fixtures; do not provision a production Temporal cluster in
ordinary CI. Serve and worker are commands of one executable/image, and both must compile.

Adding service CI does not authorize adding PostgreSQL, Valkey, vendor or full-stack tests.
Attach a local infrastructure fixture only when existing tests actually require it or that test
work is explicitly requested. Do not start databases just because a service imports PostgresNIO,
or claim mocks prove migrations/tenant isolation/idempotent SQL. Record the boundary honestly.
External provider delivery and full deployment behavior are verified in the running environment.
Do not skip an existing required suite merely to make a generic workflow green.

## Static SDK compatibility

If the service supports a static-musl build, require one released SDK build matching its
supported toolchain and deployment architecture on PRs and develop/main pushes. This is a
compatibility build, not a live service test or an image publication.

The package-test workflow can run native tests and a static SDK build together: enable
`enable_linux_static_sdk_build`, set `linux_static_sdk_versions` to the deployed release,
restrict `linux_host_archs`, and build the actual executable with release optimization and locked
resolution. Its released setup script selects the host's musl target, including ARM64. No main
snapshot SDK, unrelated architecture or additional SDK sweep is required for applications.
A service with no supported musl path records the omission instead of claiming static support.

## Release image and Foundation

Build the actual Containerfile natively for the deployment architecture; do not substitute a
host `swift build`, emulation or library-consumer build. Use the same release configuration and
lockfile for PR validation and publishing. Preserve one image for serve/worker processes.

The final image runs as an unprivileged user and contains the executable, backtracer, all SwiftPM
resource bundles and required runtime libraries. Copy the entire staging directory; copying only
the binary silently drops staged resources. In the final image:

- Inspect the executable's dynamic runtime library closure and fail for missing libraries.
- Run `--help` and `serve --help`; also `worker run --help` when that command exists.
- Do not boot production configuration, contact infrastructure or run migrations for this smoke check.

These commands catch loader and command-packaging failures; they do not establish readiness,
resource consumption by every code path, or deployed connectivity. Static binaries have no
dynamic closure to inspect; verify their execution separately.

Prefer FoundationEssentials in owned code. Inspect the actual Linux executable; the library
Foundation consumer workflow cannot validate an application. Full Foundation may be required
by a released dependency (for example PostgresNIO) or intentional internationalization. Record
that package/version or capability and ship its required libraries. Do not install a universal
no-Foundation gate that is guaranteed to fail for the documented graph. A static SDK success
alone does not prove Essentials-only code. Revisit a documented upstream requirement when the
resolved dependency changes.

## Publishing and deployment ordering

PR image jobs have read-only permissions and build/load without pushing. On deployment branches,
source/tests/static checks must succeed before the image job. Build once, smoke-check the final
image, then tag and publish that same local image with commit and branch tags. Do not rebuild
an unvalidated image in a separate publishing step. Grant `packages: write` only to publication.
Deployment runs after successful publication and retains the repository's existing environment
secret names and server/worker application identifiers. It is never a PR action.

Cancel obsolete PR runs. Serialize whole deployment workflows per branch with
`cancel-in-progress: false`; do not interrupt an active rollout or allow overlapping runs to
move a branch tag concurrently. Staging and production use separate groups. GitHub may replace
a pending run with a newer one; this convention deploys branch state and does not promise that
every intermediate commit reaches the environment. A deployment API trigger proves acceptance,
not application health; environment verification remains separate.

## Dependency updates and completion

Dependabot checks Swift and Actions weekly and targets develop. A library-only `semver/none`
label or release workflow is not a service requirement. Promote changes from staging through
the ordinary develop-to-main merge. CI itself neither merges updates nor creates releases.

Validate workflow inputs against the selected upstream release; run actionlint, YAML/shell lint,
strict formatter lint and locked tests where available. Verify the native static SDK and actual
final image when the environment supports them. Test any image-check helper against missing
libraries and worker-command failures, not just its successful branch. Use independent eval
artifact checks to catch lost gates, wrong platform, unlocked resolution or PR publication.

Completion reports distinguish local validation from GitHub/Linux/image execution that was not
performed. Updating workflows does not authorize CI monitoring, deployment, repository-setting
changes or unrelated application edits. Repository profiles must describe actual workflow gates
and their limitations.
