# Delivery

How a service moves from a commit to a running process: branches and environments, the CI that gates them, the image build, per-commit publishing, and deployment. This file owns the pipeline; environment.md owns what the deployed system looks like once it is running, and says only that images "come from delivery".

This file is the worked default: GitHub Actions, a container registry, a Dokploy-style platform reached by API. The skill's rules state the principle each piece satisfies and name the alternative, so another CI or platform passes the same gates by satisfying the same principle.

## Contents

- Branches are environments
- The workflow files
- The tests job
- The release image
- Publishing per commit
- The registry
- Deploying to the platform
- Platform configuration and its traps
- Migrations in the pipeline
- Dependency updates
- Retention

## Branches are environments

Two long-lived branches, each bound to one environment:

- **`develop` is staging.** Every commit publishes an image and deploys it — tests, image, deploy trigger, boot-time migrations, unattended. Staging is where push-and-see-it-running lives.
- **`main` is production.** Every commit publishes an image; the deploy steps exist only once a production platform does. Promotion is a merge from develop to main — after the first sync, never cherry-picks, so the histories stay converged and script or workflow fixes ride the same merge as code.

Pull requests run the tests job regardless of target branch. Deployment steps are mandatory, not gated: a missing secret or variable fails the pipeline loudly through the action's own environment checks rather than skipping the deploy and reporting green. A pipeline that silently does less than it claims is worse than a red one.

Versioning differs by what a repository is *for*. Services carry no SemVer tags and no releases: the commit is the version, the SHA is the deploy identifier. SemVer, API-breakage checks, and label-driven release automation belong to the shared packages — the protos, the swift-microservices packages, and `<project>-core` — whose consumers resolve version ranges (see *Contracts and compatibility* in the designing-swift-systems skill). A library package cuts a GitHub Release from the semver label on each merged pull request and never commits `Package.resolved`; a service executable commits it, and re-resolves it when a dependency's tag moves. Move a tag only before anything depends on it: SwiftPM remembers which commit a tag resolved to in `~/.swiftpm/security/fingerprints/<package>-*.json`, and a moved tag fails every consumer's resolve with "does not match previously recorded value" until that file is deleted on every machine that saw the old one.

## The workflow files

Each service repository carries four small workflows and a dependabot configuration:

| File | Trigger | Does |
| --- | --- | --- |
| `pull_request.yml` | every PR | the tests job |
| `develop.yml` | push to develop | tests → publish → deploy (staging) |
| `main.yml` | push to main | tests → publish (production deploy steps join when the platform exists) |
| `cleanup-images.yml` | weekly cron | prunes the registry to a recent window |
| `dependabot.yml` | weekly | Swift and Actions bumps as PRs against develop |

Third-party actions are pinned to commit SHAs with a version comment; dependabot keeps the pins moving. The organization's own actions, where any exist, are pinned by SemVer tag (see *Deploying to the platform*).

## The tests job

CI reuses `swiftlang/github-workflows`' `swift_package_test.yml`, pinned to a release tag, collapsed from its default sweep to the one cell that matches production:

```yaml
jobs:
  tests:
    name: Tests
    uses: swiftlang/github-workflows/.github/workflows/swift_package_test.yml@<tag>
    with:
      linux_swift_versions: '["<toolchain>"]'
      linux_os_versions: '["<os>"]'
      linux_host_archs: '["<arch>"]'          # the arch production runs; never test what nothing ships
      linux_build_command: "swift test --disable-automatic-resolution"
      enable_windows_checks: false             # defaults to true; refuse the surprise
```

`--disable-automatic-resolution` makes the committed `Package.resolved` the build: CI fails when the manifest and the pin drift instead of silently resolving something newer. The macOS/iOS jobs run on runners only the swiftlang organization has — leave them off. One accepted trade comes with the reuse: no dependency caching (every run resolves and compiles cold; the price of not maintaining the workflow). Keep a static Linux SDK build beside it whenever the local image path is musl, because the static SDK is where a full-Foundation import or a missing `NIOFoundationCompat` link surfaces, and nothing else in the pipeline sees it; vendored C++ in the protobuf toolchain has broken musl builds outright, which is exactly why the check runs on every change rather than being discovered at the first local build.

Private repositories have no free allotment for arm runners: a job on `ubuntu-24.04-arm` is refused before it starts when the account's billing lapses, and every run on the deployment branches fails the same way while nothing in the code changed. Either fund the account, host an arm runner of your own, or accept that publishing happens through the local path — build the image with the package's container plugin on an arm machine, push it with a write token, and trigger the platform's deploy by hand — until CI is back. A green pipeline is the normal path, not the only one.

## The release image

Published images build from a `Containerfile`, two stages, glibc:

- **Build stage** on the Swift toolchain image: `COPY ./Package.*` and `swift package resolve` as their own layer so dependency resolution caches while manifests are unchanged, then `swift build --configuration release --static-swift-stdlib --product <service>`, then stage the binary, `swift-backtrace-static`, and every `*.resources` bundle.
- **Runtime stage** on the matching minimal OS image: `ca-certificates` and `tzdata` only, an unprivileged system user with `/app` as home, the staged files copied in with that owner, `SWIFT_BACKTRACE` configured, `ENTRYPOINT ["./<service>"]`.

A `.dockerignore` beside it excludes version control, `.github`, build state, secrets patterns, and everything not needed to compile the package.

Build natively for the deployment host's architecture — an ARM host means an ARM runner and `platforms: linux/arm64` — never under emulation, which turns a release build into an hour. The static-musl container plugin remains the local `Makefile` path (see [environment.md](environment.md)); the Containerfile is the delivery path, and the two are allowed to differ because only one of them publishes — with the fallback above as the one time the local path publishes too.

## Publishing per commit

The publish job runs after tests on every push to a deployment branch: buildx builds the Containerfile with the GitHub Actions layer cache and pushes two tags —

```
ghcr.io/<organization>/<organization>-<service>:<short-sha>
ghcr.io/<organization>/<organization>-<service>:<branch>
```

The **short SHA tag is immutable** and exists for forensics and rollback; the moving branch tag (`develop`, `main`) is what the platform applications track. A deploy is therefore a trigger, not a reconfiguration: the platform pulls the branch tag it already points at. Rolling back means pinning an older SHA on the application in the platform and deploying — an operator action, deliberately outside the pipeline.

## The registry

The workflow's own `GITHUB_TOKEN` pushes, with `permissions: packages: write` on the job. One trap: a package that already exists — created by a manual push under a personal token — does not trust any repository's `GITHUB_TOKEN` until the package's *Manage Actions access* setting grants the repository write (admin, if the cleanup workflow is to delete versions). The setting is UI-only; the first pipeline push of every pre-existing package fails `permission_denied` until it is made.

## Deploying to the platform

The default platform is Dokploy. Each service is one platform application, Docker-image sourced, tracking the branch's moving tag (`:develop` on staging) with `command: ./<service> serve --migrate-database`. The deploy step is a single trigger — a SHA-pinned marketplace action that POSTs the platform's deploy endpoint and nothing else:

```yaml
      - name: Deploy to staging Dokploy
        uses: benbristow/dokploy-deploy-action@<commit-sha> # <version>
        with:
          dokploy_url: ${{ secrets.DOKPLOY_URL }}
          api_token: ${{ secrets.API_TOKEN }}
          application_id: ${{ secrets.APPLICATION_ID }}
```

Three plain secrets bind the environment; production's workflow carries the same step with its own values. The step is mandatory, not gated — a missing secret fails the pipeline loudly rather than skipping the deploy. The platform API must be reachable from the runner: a public endpoint (a tailnet Funnel included) is one HTTPS call with a bearer key; a tailnet-only endpoint means a tailnet-join action in the workflow or publish-only CI with deploys triggered from inside. The API key is a deploy credential that can reconfigure every application — rotate it on any suspicion, and keep the platform account behind a second factor.

An organization `ci` repository of composite actions remains the right home for platform logic that *churns* — versioned with plain SemVer tags dependabot bumps — but with a trigger-only deploy there is currently nothing left to centralize. The dividing line stands: **logic that changes** is centralized; **declarations that don't** (a cron line, a retention count, a package name) stay in each repository. The cleanup workflow, for instance, must live per-repo regardless — schedules only fire in the repository that hosts them, and package deletion needs the repository's own token.

## Platform configuration and its traps

One application per process — `<service>`, and `<service>-worker` running the same image with `worker run` as its command — plus Postgres as either a per-service instance or one shared instance with a database per service (see *One instance or many* in the building-swift-services skill's persistence reference), Docker-image sourced. Key files arrive as file mounts at the same paths the Compose environment used, so the service's configuration does not know which environment it is in.

**One project, one environment per deployment tier.** Staging and production can share one platform host as two *environments* of one project, each holding its full set of applications (the platform re-suffixes names, so nothing collides). Shared variables live in **each environment's own scope**, referenced by **every** application as `${{environment.KEY}}` — same keys in both environments, different values — so a promotion is purely an image-tag difference. Keep the project scope **empty**, and never mix the two: the reference form and the scope must agree. A value placed in the project scope is invisible to an app that reads `${{environment.KEY}}` — the reference still resolves, but against the environment bucket, so it silently picks up whatever stale value sits there (or nothing). A per-tier value — a webhook signing secret, a domain, a namespace — therefore belongs in its environment's scope, never the project scope; setting it project-wide is the classic "I set it but it did not take" failure. Each environment owns what must not leak across tiers: its **own database instance** (role names are cluster-wide, so two environments' `CREATE ROLE <service>_service` collide on a shared instance), its own signing keypair (one tier's tokens must not verify on the other), its own cache, and its own certificate authority. Environments share the platform's *platform services*, which live in their own projects rather than inside any application environment: the workflow engine (one cluster, a **namespace per environment**, named after the environment), the log store and dashboards, the internal CA, and the registry credential. Provisioning jobs — database creation, namespace creation, credential issuing — are disposable one-shots: created on demand, log-verified (a one-shot's failure still reports a completed deploy), and deleted immediately after, so no credential-bearing application definition outlives its use.

**The project's shared environment is the source of truth.** Everything project-wide is defined once at the project level, and each application's environment *re-declares* the keys it uses as references — `KEY=${{project.KEY}}` — keeping only what is truly service-specific as literal values. Project-level variables are not auto-injected; the explicit reference is the mechanism, and it is a feature: each application's environment remains the complete, readable list of what the process receives, while every value with more than one consumer has exactly one definition.

What belongs at the project level: the database cluster's address and administrator pair; the log store's URL and the log level; the TLS material paths; the token-verification public-key path; the serving host/port every gRPC process binds; the job orchestrator's address and namespace; organization-wide API keys — and the **service directory**: every service's internal host and port (`GRPC_<SERVICE>_HOST/PORT` for all of them, including single-consumer ones — an address is a fact about the project, not about whichever process happens to dial it today). What stays per application: the database name and its role pairs — service, internal, worker — its task queue, and any key only it holds. A well-factored service ends up with a handful of literal lines and references for everything else.

The operational rule: references resolve at deploy, not live — changing a shared value is one project-level update followed by a stop-then-deploy of each consuming application. The same variable set, with production values, is the template for the next environment.

Dokploy specifics, each learned the expensive way:

- **`command` replaces the image's entrypoint**, it does not append to it: write `./<service> serve --migrate-database`, never `serve --migrate-database`.
- **A one-shot application needs restart policy `none`**, or the platform's scheduler restarts it forever (relevant to any future job-shaped application; migrations no longer are one).
- **Application names are immutable and get a random suffix at creation.** The suffixed name is the internal DNS name — so every mTLS leaf needs the suffixed name as a SAN beside the plain service name (see *Transport security: the certificate volume* in [environment.md](environment.md)), issued against the same CA.
- **Do not link an application to a registry entry**: on this platform that designates a *cluster* registry and re-uploads every image to it on deploy — which a read-only pull token cannot do. Registry credentials entered once in the platform UI land in the host's Docker login and cover pulls for every application.
- **A crash-looping service can pin a stale spec**: after fixing configuration, stop the application entirely, then deploy, rather than deploying over the loop.
- **A green publish run is not proof the tag exists.** The production workflow is a near-copy of staging's, and the classic copy-paste failure publishes the *staging* tag from the production branch while every run stays green. When a deploy fails pulling `:main`, check the manifest with an authenticated registry call before debugging anything else. One image per service, the worker included, is what keeps this a one-tag check.

## Migrations in the pipeline

Migrations run **in the serving container, at boot**: the application's command is `serve --migrate-database`, and the process applies the list over a short-lived owner client — `PostgresClient.withClient` from swift-persistence-postgres — before the server binds (see *Migrations at boot* in the building-swift-services skill's composition reference). There is no migrate application and no pipeline ordering to maintain — a container cannot serve an unmigrated schema, because it migrates before it listens. The migration library makes the no-migration case a cheap no-op, so the flag stays on unconditionally.

The trade, accepted with open eyes: the owner credentials sit in the serving container's environment for its lifetime. The serving *process* still connects only as the confined role — the row-level-security posture is unchanged — but a compromise of the container's environment now yields the owner pair. Two residual cautions: multiple replicas of one service would race the apply at startup (fine on one node; an advisory lock before the list when replicas arrive), and a failed migration crash-loops the new task while the platform's rolling update keeps the old one serving.

Two facts boot-ordering cannot fix, and one rule that absorbs both: the old build briefly runs against the new schema during every deploy, and a rollback runs old code against a schema that migrated forward — **so migrations are expand/contract**. Adding tables, nullable columns, and indexes is always safe; renames, drops, and tightening constraints ship in a *later* commit, only after no deployed code references the old shape. A genuinely breaking migration is the rare event where the deploy is watched rather than unattended.

## Dependency updates

Dependabot targets develop (`target-branch: "develop"` on both the `swift` and `github-actions` ecosystems), so a bump lands as a PR into staging's branch, deploys to staging on merge, and reaches production by promotion like every other change. The configuration is read from the default branch, so the copy on main is the one that counts; security updates ignore the target and PR against main by design — a CVE fix offered straight at the production track is a feature. A new tag on a contract package arrives through the same door: dependabot PRs it against develop, and CI is the cross-repo integration test.

## Retention

Per-commit publishing fills a registry. Each repository carries a weekly scheduled workflow running the registry's delete-versions action, keeping the newest N (30 is a sane default). Consequences to know: a SHA older than the window cannot be re-pulled, so rollback targets are recent by construction, and recovery from a very old deploy is forward to a current SHA, not backward.
