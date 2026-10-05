# Delivery

How a service moves from a commit to a running process: branches and environments, the CI that gates them, the image build, per-commit publishing, and deployment. This file owns publishing and deployment; [services-ci.md](services-ci.md) owns application validation and [library-ci.md](library-ci.md) owns reusable package CI. environment.md owns what the deployed system looks like once it is running, and says only that images "come from delivery".

This file is the worked default: GitHub Actions, a container registry, a Dokploy-style platform reached by API. The skill's rules state the principle each piece satisfies and name the alternative, so another CI or platform passes the same gates by satisfying the same principle.

## Contents

- Branches are environments
- Validation before publishing
- The release image
- Publishing per commit
- The registry
- Deploying to the platform
- Platform configuration and its traps
- Migrations in the pipeline
- Retention

## Branches are environments

Two long-lived branches, each bound to one environment:

- **`develop` is staging.** Every commit publishes an image and deploys it — tests, image, deploy trigger, boot-time migrations, unattended. Staging is where push-and-see-it-running lives.
- **`main` is production.** Every commit publishes an image; the deploy steps exist only once a production platform does. Promotion is a merge from develop to main — after the first sync, never cherry-picks, so the histories stay converged and script or workflow fixes ride the same merge as code.

Pull requests follow [services-ci.md](services-ci.md) regardless of target branch and never publish or deploy. After successful validation and publication, deployment steps are mandatory: a missing secret or variable fails loudly rather than skipping deployment and reporting green. A pipeline that silently does less than it claims is worse than a red one.

Versioning differs by what a repository is *for*. Services carry no SemVer tags and no releases: the commit is the version, the SHA is the deploy identifier. SemVer labels and releases belong to the shared packages — the protos, the swift-microservices packages, and `<project>-core` — whose consumers resolve version ranges (see *Contracts and compatibility* in the designing-swift-systems skill); each releases by its recorded mechanism, label-based Auto Release or hand-cut bare tags. Libraries run no automatic API-breakage check; SemVer labels and review record API impact. A library records SemVer impact without committing `Package.resolved`; a service executable commits it. Tags never move once anything resolves them: SwiftPM remembers which commit a tag resolved to in `~/.swiftpm/security/fingerprints/<package>-*.json`, and a moved tag fails every consumer's resolve with "does not match previously recorded value" until that file is deleted on every machine that saw the old one. If an upstream tag was moved anyway, that deletion and a fresh resolve are the recovery.

## Validation before publishing

Follow [services-ci.md](services-ci.md) for workflow layout, source quality, locked tests, static
SDK compatibility, executable Foundation/runtime inspection and weekly dependency updates.
PRs validate without publishing or deploying. Deployment branches pass their required checks,
build and smoke-check the final image, and publish that same image before deployment.

## The release image

How the image is built is the project's choice, made once and recorded in `AGENTS.md` from the project's direction:

- a **`Containerfile`** built with Docker (Buildx) or Apple's `container` tool;
- a **static Linux SDK** binary (`swift build --swift-sdk <arch>-swift-linux-musl`) copied into a minimal base image;
- **`swift-container-plugin`** (`swift package build-container-image`), with no daemon involved.

Every choice satisfies the same contract: a release build from the locked graph (`--disable-automatic-resolution`, with the strict flags in [services-ci.md](services-ci.md#locked-dependency-resolution) where the build runs a compiler step CI controls), staged with the backtracer and every `*.resources` bundle; a runtime that runs as an unprivileged user, carries `ca-certificates` and `tzdata` where it has an OS layer, and configures `SWIFT_BACKTRACE`; and one image per service, serve and worker alike. The image CI validates is the image it publishes.

The worked example is a two-stage glibc `Containerfile`:

- **Build stage** on the Swift toolchain image: `COPY ./Package.*` and `swift package --disable-automatic-resolution resolve` as their own layer so dependency resolution caches while manifests are unchanged, then the release build command from [services-ci.md](services-ci.md#locked-dependency-resolution) with `--static-swift-stdlib --product <service>`, then stage the binary, `swift-backtrace-static`, and every `*.resources` bundle.
- **Runtime stage** on the matching minimal OS image: `ca-certificates` and `tzdata`, any additional shared libraries required by the inspected release binary, an unprivileged system user with `/app` as home, the staged files copied in with that owner, `SWIFT_BACKTRACE` configured, `ENTRYPOINT ["./<service>"]`.

A `.dockerignore` beside it excludes version control, `.github`, build state, secrets patterns, and everything not needed to compile the package.

Build natively for the deployment host's architecture — an ARM host means an ARM runner and `platforms: linux/arm64` — never under emulation, which turns a release build into an hour. A local build may use a different tool from the published path (see [environment.md](environment.md)); only the published path is release evidence, except when refused CI runners force publishing from the local build (the skill's rule 6).

## Publishing per commit

The image job runs after all checks on a deployment-branch push: the project's image tool builds the native image (in the worked example, Buildx loads the Containerfile image using the GitHub Actions layer cache), the final image is smoke-checked, and that same image is pushed with two tags —

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
        uses: benbristow/dokploy-deploy-action@<commit-sha>  # <version>
        with:
          dokploy_url: ${{ secrets.DOKPLOY_URL }}
          api_token: ${{ secrets.API_TOKEN }}
          application_id: ${{ secrets.APPLICATION_ID }}
```

Three plain secrets bind the environment; production's workflow carries the same step with its own values. The step is mandatory, not gated — a missing secret fails the pipeline loudly rather than skipping the deploy. The platform API must be reachable from the runner: a public endpoint (a tailnet Funnel included) is one HTTPS call with a bearer key; a tailnet-only endpoint means a tailnet-join action in the workflow or publish-only CI with deploys triggered from inside. The API key is a deploy credential that can reconfigure every application — rotate it on any suspicion, and keep the platform account behind a second factor.

An organization `ci` repository of composite actions remains the right home for platform logic that *churns* — versioned with plain SemVer tags dependabot bumps — but with a trigger-only deploy there is currently nothing left to centralize. The dividing line stands: **logic that changes** is centralized; **declarations that don't** (a cron line, a retention count, a package name) stay in each repository. The cleanup workflow, for instance, must live per-repo regardless — schedules only fire in the repository that hosts them, and package deletion needs the repository's own token.

## Platform configuration and its traps

One application per process — `<service>`, and `<service>-worker` running the same image with `./<service> worker run` as its command — plus Postgres as a per-service instance, one shared instance with a database per service, or one database with a schema per service (see *Where a service's data lives* in the building-swift-services skill's persistence reference), Docker-image sourced. Key files arrive as file mounts at the same paths the Compose environment used, so the service's configuration does not know which environment it is in.

**One project, one environment per deployment tier.** Keep the services and their supporting applications in one Dokploy project, with separate staging and production environments. Shared values live in each environment and are referenced explicitly as `${{environment.KEY}}`. Use application-local values for role secrets and task queues. Do not mix this with project-scope references for tier-specific values. Each tier has separate database state, JWT keys, and certificate trust. References resolve on deployment; redeploy affected consumers after changing them.

**Smallstep in the services project.** Deploy a persistent `smallstep/step-ca` service in each environment on the private service network. Mount its configuration, database, intermediate signing material, and password file only there; keep the root key offline. Do not expose a CA administration endpoint through the application gateway. Pin its image and back up its state; a redeploy must not initialize a new CA.

Run a `smallstep/step-cli` renewer for each workload credential directory, sharing it read-write with the renewer and read-only with the application. On a single Dokploy host, shared bind paths or named volumes must refer to the same storage; for rescheduling across nodes, explicitly provide shared storage or reenrollment. A project label alone does not share files or create a network. Configure and verify both. Keep Temporal credentials separate at `/run/temporal-tls`.

Initial enrollment is a short-lived provisioning operation. Verify its result, remove enrollment secrets and disposable job definitions, and keep the long-running renewers. The CA and renewers remain deployed. Use the [certificate lifecycle](environment.md#transport-security-the-certificate-volume) for enrollment, renewal, rekeying, expiry monitoring, and CA overlap. Swift’s reloader is the file consumer, not the issuer.

Shared platform services can remain external when the environment already supplies them. For a shared Temporal cluster, namespaces separate application resources but do not establish mTLS authorization; configure and verify transport admission independently. See [Dokploy variable scopes](https://docs.dokploy.com/docs/core/variables).

Dokploy specifics, each learned the expensive way:

- **`command` replaces the image's entrypoint**, it does not append to it: write `./<service> serve --migrate-database`, never `serve --migrate-database`.
- **A one-shot application needs restart policy `none`**, or the platform's scheduler restarts it forever (any job-shaped application, including a `migrate` one-shot where the project runs migrations as a job rather than at boot).
- **Application names are immutable and get a random suffix at creation.** The suffixed name is the internal DNS name — so every mTLS leaf needs the suffixed name as a SAN beside the plain service name (see *Transport security: the certificate volume* in [environment.md](environment.md)), issued against the same CA.
- **Do not link an application to a registry entry**: on this platform that designates a *cluster* registry and re-uploads every image to it on deploy — which a read-only pull token cannot do. Registry credentials entered once in the platform UI land in the host's Docker login and cover pulls for every application.
- **A crash-looping service can pin a stale spec**: after fixing configuration, stop the application entirely, then deploy, rather than deploying over the loop.
- **A green publish run is not proof the tag exists.** The production workflow is a near-copy of staging's, and the classic copy-paste failure publishes the *staging* tag from the production branch while every run stays green. When a deploy fails pulling `:main`, check the manifest with an authenticated registry call before debugging anything else. One image per service, the worker included, is what keeps this a one-tag check.

## Migrations in the pipeline

By default, migrations run **in the serving container, at boot**: the application's command is `serve --migrate-database`, and the process applies the list over a short-lived owner client — `PostgresClient.withClient` from swift-persistence-postgres — before the server binds (see *Migrations at boot* in the building-swift-services skill's composition reference). By default there is no migrate application and no pipeline ordering to maintain — a container cannot serve an unmigrated schema, because it migrates before it listens. The migration library makes the no-migration case a cheap no-op, so the flag stays on unconditionally.

The trade, accepted with open eyes: the owner credentials sit in the serving container's environment for its lifetime. The serving *process* still connects only as the confined role — the row-level-security posture is unchanged — but a compromise of the container's environment now yields the owner pair. Two residual cautions: multiple replicas of one service would race the apply at startup (fine on one replica; when replicas arrive, the project chooses an advisory lock around the list or a `migrate` one-shot before the rollout), and a failed migration crash-loops the new task while the platform's rolling update keeps the old one serving.

Two facts boot-ordering cannot fix, and one rule that absorbs both: the old build briefly runs against the new schema during every deploy, and a rollback runs old code against a schema that migrated forward — **so migrations are expand/contract**. Adding tables, nullable columns, and indexes is always safe; renames, drops, and tightening constraints ship in a *later* commit, only after no deployed code references the old shape. A genuinely breaking migration is the rare event where the deploy is watched rather than unattended.

## Retention

Per-commit publishing fills a registry. Each repository carries a weekly scheduled workflow running the registry's delete-versions action, keeping the newest N (30 is a sane default). Consequences to know: a SHA older than the window cannot be re-pulled, so rollback targets are recent by construction, and recovery from a very old deploy is forward to a current SHA, not backward.
