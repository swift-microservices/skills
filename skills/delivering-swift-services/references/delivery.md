# Delivery

How a service moves from a commit to a running process: branches and environments, the release image, per-commit publishing, deployment, migrations, and retention. [services-ci.md](services-ci.md) owns application validation and [library-ci.md](library-ci.md) reusable package CI; [environment.md](environment.md) owns what the deployed system looks like once it runs, and [certificates.md](certificates.md) its credentials.

This file is the worked default: GitHub Actions, a container registry, a Containerfile, and a Dokploy-style platform reached by API. The skill's rules state the principle each piece satisfies and name the alternative, so another CI or platform passes the same gates by satisfying the same principle.

## Contents

- [Branches are environments](#branches-are-environments)
- [Validation before publishing](#validation-before-publishing)
- [The release image](#the-release-image)
- [Local builds](#local-builds)
- [Publishing per commit](#publishing-per-commit)
- [The registry and retention](#the-registry-and-retention)
- [Deploying to the platform](#deploying-to-the-platform)
- [Platform configuration and its traps](#platform-configuration-and-its-traps)
- [Migrations](#migrations)

## Branches are environments

Two long-lived branches, each bound to one environment:

- **`develop` is staging.** Every commit publishes an image and deploys it: tests, image, deploy trigger, boot-time migrations, unattended.
- **`main` is production.** Every commit publishes an image; the deploy steps exist once a production platform does. Promotion is a merge from develop to main, never a steady-state cherry-pick, so histories stay converged and workflow fixes ride the same merge as code.

Pull requests follow [services-ci.md](services-ci.md) regardless of target branch and never publish or deploy. After successful validation and publication, deployment steps are mandatory: a missing secret or variable fails loudly rather than skipping deployment and reporting green.

Versioning differs by what a repository is for. Services carry no SemVer tags and no releases: the commit is the version, the SHA the deploy identifier. SemVer belongs to the shared packages consumers resolve by range (the protos, the swift-microservices packages, the organization's core package), each released by its recorded mechanism: label-based Auto Release or hand-cut bare tags. A library records API impact with labels and never commits `Package.resolved`; a service executable commits it. Tags never move once anything resolves them: SwiftPM records each tag's commit in `~/.swiftpm/security/fingerprints/<package>-*.json`, and a moved tag fails every consumer's resolve with "does not match previously recorded value" until that file is deleted on every machine that saw the old one, which is also the recovery when an upstream tag moved anyway.

## Validation before publishing

Follow [services-ci.md](services-ci.md) for workflow layout, source quality, locked tests, static SDK compatibility, final-image inspection, and weekly dependency updates. Deployment branches pass their required checks, build and smoke-check the final image, and publish that same image before deployment.

## The release image

The image contract, whichever tool builds it:

- a release build from the locked graph (`--disable-automatic-resolution`, with the strict flags in [services-ci.md](services-ci.md#locked-dependency-resolution) wherever the build runs a compiler step CI controls);
- the executable, `swift-backtrace-static`, and every `*.resources` bundle staged together, with `SWIFT_BACKTRACE` configured;
- `ca-certificates` and `tzdata` where the image has an OS layer;
- an unprivileged user, whose numeric group the certificate renewers write with (see [certificates.md](certificates.md#files-owners-and-mounts));
- one image per service, serve and worker alike, built natively for the deployment host's architecture (an ARM host means an ARM runner and `linux/arm64`), never under emulation;
- the image CI validates is the image it publishes.

How it is built is the project's choice, recorded once in `AGENTS.md`:

- **A `Containerfile`** built with Docker Buildx or Apple's `container` (the worked example). Copy [the Containerfile](../assets/Containerfile) and [the ignore file](../assets/dockerignore) (as `.dockerignore`) and replace the product name. Its build stage resolves `Package.*` in its own cached layer, builds with the locked strict flags and `--static-swift-stdlib`, and stages the binary, backtracer, and bundles; its runtime stage installs CA certificates and time-zone data, creates an unprivileged system user `app` with `/app` as its home, copies the staging directory there owned by that user, and runs `/app/<service>` as it.
- **A static Linux SDK binary** (`swift build --swift-sdk <arch>-swift-linux-musl`) copied into a minimal base image that sets an unprivileged user.
- **`swift-container-plugin`** (`swift package build-container-image`), with no daemon. It conflicts with the contract in two places, so the project records how it meets them: its images default to root, and the binary sits at `/<product>`. Set a non-root user if the plugin version supports one (or a base image whose user it carries through), and confirm with `docker image inspect --format '{{.Config.User}}'`; otherwise record the root image as a project exception in `AGENTS.md`, with read-only mounts and file ownership as the compensating control. Pass `/<product>` as the check script's binary path, and give the platform that path in its command.

## Local builds

Each service carries a `Makefile` wrapping the project's local build, for a workstation and as the fallback when CI cannot run; the short SHA is the tag CI would push:

```make
TAG ?= $(shell git rev-parse --short=7 HEAD)
IMAGE ?= ghcr.io/<organization>/<organization>-<service>

build:
	docker buildx build --platform linux/arm64 --load --tag $(IMAGE):$(TAG) .

.PHONY: build
```

On `swift-container-plugin`, build the plugin's host tool from the locked graph first, then the image with the static SDK:

```make
TAG ?= $(shell git rev-parse --short=7 HEAD)
IMAGE ?= ghcr.io/<organization>/<organization>-<service>
SWIFT_SDK ?= aarch64-swift-linux-musl

build:
	swift build --configuration release --disable-automatic-resolution --product containertool
	swift package --disable-automatic-resolution --swift-sdk $(SWIFT_SDK) \
		--configuration release \
		--allow-network-connections all build-container-image \
		--product <service> --repository $(IMAGE) --tag $(TAG)

.PHONY: build
```

A local build may use a different tool from the published path; only the published path is release evidence, except when refused CI runners force publishing from the local build (the skill's rule 6). A plugin image's creation date is the epoch, so image age says nothing about freshness; probe a feature (`--help` listing a subcommand) instead.

## Publishing per commit

The image job runs after all checks on a deployment-branch push: the image tool builds the native image (in the worked example, Buildx loads it using the GitHub Actions layer cache), the final image is smoke-checked, and that same image is pushed with two tags:

```
ghcr.io/<organization>/<organization>-<service>:<short-sha>
ghcr.io/<organization>/<organization>-<service>:<branch>
```

The short SHA tag is immutable and exists for forensics and rollback; the moving branch tag (`develop`, `main`) is what the platform applications track. A deploy is therefore a trigger, not a reconfiguration. Rolling back means pinning an older SHA on the application and deploying, an operator action outside the pipeline.

## The registry and retention

The workflow's own `GITHUB_TOKEN` pushes, with `permissions: packages: write` on the publishing job only. A package that already exists (created by a manual push under a personal token) does not trust any repository's token until its *Manage Actions access* setting grants the repository write (admin, for the cleanup workflow to delete versions). The setting is UI-only; the first pipeline push of every pre-existing package fails `permission_denied` until it is made.

Per-commit publishing fills a registry. Each repository carries [the weekly cleanup workflow](../assets/service-cleanup-images.yml) (`.github/workflows/cleanup-images.yml`, the package name filled in), keeping the newest 30 versions. It lives in each repository because schedules fire only in the repository that hosts them and deletion needs that repository's token. A SHA older than the window cannot be pulled again, so rollback targets are recent by construction, and recovery from a very old deploy is forward to a current SHA.

## Deploying to the platform

Each process is one platform application, image-sourced, tracking the branch's moving tag. The deploy step is a single trigger: a SHA-pinned action that calls the platform's deploy endpoint and nothing else, bound to three plain secrets. A service with a worker deploys the worker application from the same image in a second step with its own application id:

```yaml
      - name: Deploy to staging Dokploy
        uses: benbristow/dokploy-deploy-action@<commit-sha>  # <version>
        with:
          dokploy_url: ${{ secrets.DOKPLOY_URL }}
          api_token: ${{ secrets.API_TOKEN }}
          application_id: ${{ secrets.APPLICATION_ID }}
      - name: Deploy worker to staging Dokploy
        uses: benbristow/dokploy-deploy-action@<commit-sha>  # <version>
        with:
          dokploy_url: ${{ secrets.DOKPLOY_URL }}
          api_token: ${{ secrets.API_TOKEN }}
          application_id: ${{ secrets.WORKER_APPLICATION_ID }}
```

Production's workflow carries the same steps with `PROD_DOKPLOY_URL`, `PROD_API_TOKEN`, `PROD_APPLICATION_ID`, and `PROD_WORKER_APPLICATION_ID`. The steps are mandatory, never conditional on a secret. The platform API must be reachable from the runner: a public endpoint is one HTTPS call with a bearer key; a tailnet-only endpoint means a tailnet-join step or publish-only CI with deploys triggered from inside. The API key can reconfigure every application: rotate it on any suspicion and keep the platform account behind a second factor.

## Platform configuration and its traps

One application per process: `<service>` with the command `/app/<service> serve --migrate-database`, and `<service>-worker` running the same image with `/app/<service> worker run` (the binary's real path: `/<service>` on a plugin image). Postgres follows the project's placement. Key files arrive as file mounts at the same paths Compose uses, so configuration does not know which environment it is in.

**One project, one environment per deployment tier.** Keep the services, the CA, and their supporting applications in one project with separate staging and production environments. Shared values live in each environment and are referenced as `${{environment.KEY}}`; the project scope stays empty; application-local values hold role secrets and task queues. Each tier has its own database state, JWT keys, and CA. References resolve on deployment, so redeploy consumers after changing them. A shared platform service (a Temporal cluster) may stay external; its namespaces separate resources but do not authorize transport, which [certificates.md](certificates.md#temporal-tls) decides. See [Dokploy variable scopes](https://docs.dokploy.com/docs/core/variables).

The CA, its enrollment one-shots, and the renewers are deployed as [certificates.md](certificates.md) describes, on the services' private network. Dokploy specifics, each learned the expensive way:

- **`command` replaces the image's entrypoint**: write the binary's path, `/app/<service> serve --migrate-database`, never `serve --migrate-database`.
- **A one-shot needs restart policy `none`**, or the scheduler restarts it forever (enrollment, permission initialization, a `migrate` one-shot).
- **Application bind mounts cannot be made read-only through the API.** Ownership enforces the split instead: the renewer's UID owns the directory and files, and the application runs as a different UID in the renewer's group with read-only file modes (see [certificates.md](certificates.md#files-owners-and-mounts)).
- **Names get a random suffix at creation and cannot change.** Give each workload a stable network alias on the platform's shared network and issue SANs for the alias (and the suffixed name), so a recreated application keeps a valid certificate and clients dial a name that never changes.
- **Bind-mounted files persist only under the platform's files directory** (`../files/` relative to a Compose resource). Keep renewal scripts, the CA root, and enrollment tokens there; any other host path is not managed and may vanish.
- **Volumes shared between resources are external, named, and primed first.** Create each credential volume with an explicit name, run permission initialization and enrollment into it, and declare it `external: true` in every resource that mounts it; otherwise the platform creates an empty, project-prefixed volume and the application starts without credentials. On more than one node, provide shared storage or re-enroll on the new node.
- **Disable auto-deploy on the CA's resource**, so a push never restarts or re-creates the CA.
- **Swarm's default stop grace period is ten seconds**, which kills a draining worker mid-Activity. Set the worker application's stop grace period longer than its longest Activity's drain.
- **A worker exits 0 on SIGTERM after draining.** A worker whose run loop throws after a graceful drain fails its `ServiceGroup` and exits 1, which cancels its other services and loses its last log lines; see the workflow skill's [worker reference](../../orchestrating-temporal-workflows/references/worker.md).
- **Do not link an application to a registry entry**: that designates a cluster registry and re-uploads every image on deploy, which a read-only pull token cannot do. Registry credentials entered once in the platform UI cover pulls for every application.
- **A crash-looping application can pin a stale spec**: after fixing configuration, stop it, then deploy.
- **A green publish run is not proof the tag exists.** The production workflow is a near-copy of staging's, and the classic copy-paste failure publishes the staging tag from the production branch while every run stays green. When a deploy fails pulling `:main`, check the manifest with an authenticated registry call first.

## Migrations

By default migrations run in the serving container at boot: the command is `serve --migrate-database`, and the process applies the list over a short-lived owner client (`PostgresClient.withClient` from swift-persistence-postgres) before the server binds (see *Migrations at boot* in the building skill's [composition reference](../../building-swift-services/references/composition.md#migrations-at-boot)). There is no migrate application and no pipeline ordering: a container cannot serve an unmigrated schema, because it migrates before it listens. Applying an already-applied list is a cheap no-op, so the flag stays on.

The accepted price: the owner pair sits in the serving container's environment for its lifetime. The serving process still connects only as its confined roles, so row-level security is unchanged, but a compromise of the container's environment yields the owner pair. With one shared owner across databases, that pair reaches every service's database, so give each database its own owner. Multiple replicas would race the apply at startup; when replicas arrive, the project records an advisory lock around the list or a `migrate` one-shot before the rollout. A failed migration crash-loops the new task while the rolling update keeps the old one serving.

The migration library refuses a list whose order differs from what a database already applied: it throws, it does not revert. Appending a migration, a role added later included, applies in place; inserting one before applied migrations means a fresh database (`docker compose down -v` locally), never an in-place `up`.

The old build briefly runs against the new schema during every deploy, and a rollback runs old code against a schema that moved forward, so migrations are expand/contract: add tables, nullable columns, and indexes freely; ship renames, drops, and tightened constraints in a later commit, once no deployed code references the old shape. A genuinely breaking migration is the rare deploy that is watched rather than unattended.
