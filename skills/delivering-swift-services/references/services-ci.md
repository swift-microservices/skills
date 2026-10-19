# Service CI

The standard CI for every deployable Swift executable: a service, a gateway, a monolith, and the
workers that run its image. Every service gets the same shape; a repository that differs records
each difference as an exception in its `AGENTS.md`, as for libraries (see
[Recording the profile](library-ci.md#recording-the-profile)). Publishing, deployment, and
rollback are [delivery.md](delivery.md)'s; library CI is [library-ci.md](library-ci.md)'s.

## Contents

- [The standard shape](#the-standard-shape)
- [Callers and shared workflows](#callers-and-shared-workflows)
- [The deployed toolchain](#the-deployed-toolchain)
- [Source quality and headers](#source-quality-and-headers)
- [Locked dependency resolution](#locked-dependency-resolution)
- [Private dependencies](#private-dependencies)
- [Tests and capability coverage](#tests-and-capability-coverage)
- [The release image and Foundation](#the-release-image-and-foundation)
- [Exceptions](#exceptions)

## The standard shape

| Event | Jobs |
| --- | --- |
| Pull request | Soundness, tests, and an image build that is checked and never pushed |
| Push to main | The same checks; then the image is published once as `:<commit-sha>` and deployed to staging |
| Deploy production, by hand | The latest main commit, or a chosen one, deployed only if staging ran it |
| Weekly | Old image versions pruned |
| Dependabot | Weekly Swift and Actions update pull requests against main |

`main` is the only long-lived branch. A service carries no SemVer, label gate, or release: the
commit is its version. There are no scheduled test runs, snapshot toolchains, or macOS and
Windows jobs.

## Callers and shared workflows

A service's workflows only call shared ones; they hold no logic of their own. Soundness and tests
come from swiftlang/github-workflows; the image, deployment, and cleanup come from
[swift-microservices/ci](https://github.com/swift-microservices/ci), whose README documents
their inputs. Copy the templates and fill in the product, image repository, and Dokploy
application IDs:

- [service-pull-request.yml](../assets/service-pull-request.yml) → `.github/workflows/pull_request.yml`
- [service-main.yml](../assets/service-main.yml) → `.github/workflows/main.yml`
- [service-deploy.yml](../assets/service-deploy.yml) → `.github/workflows/deploy.yml`
- [service-cleanup-images.yml](../assets/service-cleanup-images.yml) → `.github/workflows/cleanup-images.yml`
- [service-dependabot.yml](../assets/service-dependabot.yml) → `.github/dependabot.yml`
- [Containerfile](../assets/Containerfile) and [dockerignore](../assets/dockerignore) → `Containerfile` and `.dockerignore`
- [Makefile](../assets/Makefile) and [delivery.sh](../assets/delivery.sh) → `Makefile` and `scripts/delivery.sh`, the pipeline's steps run locally (see [delivery.md](delivery.md#local-builds))

`application_ids` is a JSON list in deploy order: the application that runs migrations first,
then its worker. Pass `build_target` only when the service image is not the Containerfile's last
stage. Pin every reusable workflow to its latest release's full commit, with the release in a
comment; the ci repository passes secrets explicitly, because `secrets: inherit` does not cross
organizations. The repository's secrets are `DOKPLOY_URL` and `DOKPLOY_TOKEN`, plus
`PACKAGES_TOKEN` with private dependencies.

## The deployed toolchain

A service tests what production runs: one released toolchain, one Linux distribution, and the
deployment host's architecture, the same as the image's build stage. The templates use Swift 6.3,
Ubuntu Noble, and aarch64. Raise them together, in the tests' `linux_swift_versions`, the
soundness `format_check_container_image`, and the Containerfile's `FROM`, as in the floor
checklist in [library-ci.md](library-ci.md#toolchains); never move an application to the library
matrix.

## Source quality and headers

Soundness turns off `api_breakage_check_enabled` and `docs_check_enabled`, which are library
gates, and keeps the rest. Prefer the [sample formatter](library-ci.md#formatting-and-headers)
and the compact header. A repository that records its own formatter or non-uniform headers (such
as Xcode author headers) keeps them, never mass-reformats, and records
`license_header_check_enabled: false` as an exception; formatter lint stays on.

Tests and the image build use warnings as errors, explicit target dependency import checking,
and explicit `Sendable`.

A service that runs `swift-openapi-generator`, such as an HTTP gateway, sets warnings as errors
in `Package.swift` instead: `.treatAllWarnings(as: .error)` on every target except the one the
generator writes into, and no `-warnings-as-errors` in `make test`, the test jobs, or the
Containerfile. The generator writes `package import` lines its output does not always use
(apple/swift-openapi-generator#946), and no warning group covers them on Swift 6.3.

## Locked dependency resolution

A service tracks its validated `Package.resolved`, dependency-update pull requests included, and
every test and image build uses it with `--disable-automatic-resolution`, which fails on a stale
manifest and lockfile pair instead of updating the graph. Dependencies use released remote
requirements: no local paths or branches. The Containerfile resolves `Package.*` in its own
cached layer before copying the sources:

```dockerfile
RUN --mount=type=secret,id=netrc,target=/root/.netrc swift package --disable-automatic-resolution resolve
RUN swift build --configuration release --disable-automatic-resolution \
    --static-swift-stdlib --explicit-target-dependency-import-check error \
    -Xswiftc -warnings-as-errors -Xswiftc -require-explicit-sendable --product <service>
```

## Private dependencies

Neither the repository's `GITHUB_TOKEN` nor swiftlang's workflows can read another private
repository. A service that depends on one:

- calls the ci repository's `tests.yml` in place of swiftlang's `swift_package_test.yml`, with the
  same inputs and `secrets: PACKAGES_TOKEN: ${{ secrets.PACKAGES_TOKEN }}`;
- passes the same secret to `build-image.yml`, which hands it to the build as the `netrc` secret
  the Containerfile mounts for `swift package resolve` only, so it never enters a layer;
- stores `PACKAGES_TOKEN` as a repository secret: a fine-grained token whose resource owner is
  the organization, limited to the private package repositories, with Contents read-only;
- gives Dependabot the same token as a Dependabot secret (Dependabot cannot read Actions
  secrets) and a `git` registry its Swift updates use:

  ```yaml
  registries:
    github:
      type: git
      url: https://github.com
      username: x-access-token
      password: ${{secrets.PACKAGES_TOKEN}}
  updates:
    - package-ecosystem: swift
      directory: /
      registries: [github]
      schedule:
        interval: weekly
  ```

A local build passes `--secret id=netrc,src=$HOME/.netrc`. Without a secret the mount is empty
and public dependencies resolve as before.

## Tests and capability coverage

Run the existing focused suites on the deployed toolchain and architecture: core behavior,
configuration, and the loopback RPC, HTTP, and JWT tests that exist. Temporal services keep
their time-skipping, worker-registration, and replay coverage, using the SDK's test server;
`serve` and `worker run` are commands of one executable, and both compile.

Adding CI does not add PostgreSQL, cache, vendor, or full-stack tests. Attach infrastructure only
when existing tests need it or that work is requested, and never claim mocks prove migrations or
tenant isolation. Never skip a required suite to make a workflow green.

## The release image and Foundation

`build-image.yml` builds the actual release image natively for linux/arm64 from the Containerfile
and checks it before anything is published: it runs as an unprivileged user, and `ldd` finds
every library the executable links (a static binary passes). It does not start the image; a
release first runs on staging. On a push to main it then pushes that same image, never a
rebuild, as `:<commit-sha>`, once.

Prefer FoundationEssentials in owned code. The library Foundation-linking check does not apply
to an executable: inspect the binary, and record a dependency that requires full Foundation
(PostgresNIO, for example) with its version, revisiting it when the dependency changes.

## Exceptions

As for libraries, each is recorded in the `## CI` section of `AGENTS.md`:

- **Non-uniform headers:** `license_header_check_enabled: false`, formatter lint kept.
- **Another image tool** (a static Linux SDK binary, `swift-container-plugin`): the project
  replaces `build-image.yml` with its own image job meeting the same contract in
  [delivery.md](delivery.md#the-release-image), and adds a static SDK build to the tests job when
  the image uses one.
- **A database or other service in tests:** a local tests workflow with the service container,
  as in the library exception, keeping the deployed toolchain.
