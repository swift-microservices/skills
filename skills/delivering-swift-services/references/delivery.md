# Delivery

How a service moves from a commit to a running process: the branch and its environments, the release image, per-commit publishing, deployment, migrations, and retention. [services-ci.md](services-ci.md) owns application validation and [library-ci.md](library-ci.md) reusable package CI; [environment.md](environment.md) owns what the deployed system looks like once it runs, and [certificates.md](certificates.md) its credentials.

This file is the worked default: GitHub Actions, a container registry, a Containerfile, and a Dokploy-style platform reached by API. The skill's rules state the principle each piece satisfies and name the alternative, so another CI or platform passes the same gates by satisfying the same principle.

## Contents

- [One branch, two environments](#one-branch-two-environments)
- [Validation before publishing](#validation-before-publishing)
- [The release image](#the-release-image)
- [Local builds](#local-builds)
- [Publishing per commit](#publishing-per-commit)
- [The registry and retention](#the-registry-and-retention)
- [Deploying to the platform](#deploying-to-the-platform)
- [Platform configuration and its traps](#platform-configuration-and-its-traps)
- [Migrations](#migrations)

## One branch, two environments

`main` is the only long-lived branch, and every commit on it is a release candidate:

- **Staging follows main.** Every push validates, publishes the commit's image, and deploys it to staging, unattended, with boot-time migrations.
- **Production is a decision.** The service's Deploy production workflow, run by hand, deploys the latest main commit or a chosen one, and refuses a commit whose push did not deploy it to staging successfully. Deploying an older commit is the rollback; nothing is rebuilt.

Pull requests follow [services-ci.md](services-ci.md) and never publish or deploy. Deployments are serialized per environment and never cancelled midway. After successful validation and publication, deployment is mandatory: a missing secret or application fails the run loudly rather than reporting green.

Versioning differs by what a repository is for. Services carry no SemVer tags and no releases: the commit is the version and the deploy identifier. SemVer belongs to the shared packages consumers resolve by range (the protos, the swift-microservices packages, the organization's core package), released by their recorded mechanism. A library records API impact with labels and never commits `Package.resolved`; a service executable commits it. Tags never move once anything resolves them: SwiftPM records each tag's commit in `~/.swiftpm/security/fingerprints/<package>-*.json`, and a moved tag fails every consumer's resolve with "does not match previously recorded value" until that file is deleted on every machine that saw the old one, which is also the recovery when an upstream tag moved anyway.

## Validation before publishing

Follow [services-ci.md](services-ci.md) for the workflows, source quality, locked tests, the final-image checks, and weekly dependency updates. A push to main passes its checks, builds and checks the final image, and publishes that same image before deploying it.

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
- **`swift-container-plugin`** (`swift package build-container-image`), with no daemon. It conflicts with the contract in two places, so the project records how it meets them: its images default to root, and the binary sits at `/<product>`. Set a non-root user if the plugin version supports one (or a base image whose user it carries through), and confirm with `docker image inspect --format '{{.Config.User}}'`; otherwise record the root image as a project exception in `AGENTS.md`, with read-only mounts and file ownership as the compensating control. Give the platform that path in its command.

## Local builds

Each service carries [the Makefile](../assets/Makefile) and [delivery.sh](../assets/delivery.sh) (as `scripts/delivery.sh`), which run the pipeline's steps from a workstation, the fallback when CI cannot run. Replace the image repository:

| Target | What it does |
| --- | --- |
| `make test` | The tests CI runs, on the committed graph with the strict flags |
| `make build` | The release image, loaded locally and never pushed |
| `make publish` | Pushes HEAD's image once as `:<commit-sha>`; refuses a dirty tree or a commit not on `origin/main`, and skips a tag that exists |
| `make stage` | Deploys `COMMIT` (default HEAD) by digest to the staging applications, in order, waiting for each |
| `make deploy` | Deploys `COMMIT` by digest to production, only if every staging application reports a successful deployment titled with its short SHA |

The registry credentials come from `~/.netrc` (`machine ghcr.io`, a token with `write:packages`); the script reads the rest from the environment or the git-ignored `.env`, without sourcing it, and the IDs are the workflows' `application_ids`, space-separated:

```
DOKPLOY_URL=https://dokploy.example.com
# The platform's API key; .env is never committed.
DOKPLOY_TOKEN=
STAGING_APPLICATION_IDS="<service-id> <worker-id>"
PRODUCTION_APPLICATION_IDS="<service-id> <worker-id>"
```

Production checks the platform's staging deployments, not a pipeline run, so a commit staged locally goes to production with `make deploy`, and one staged by CI with either.

On `swift-container-plugin`, the Makefile adds and exports `PRODUCT := <service>` and `SWIFT_SDK ?= aarch64-swift-linux-musl`; `build` becomes `swift build --configuration release --disable-automatic-resolution --swift-sdk $(SWIFT_SDK) --product $(PRODUCT)`, and `publish` in `delivery.sh` builds the plugin's host tool from the locked graph, then the image with the static SDK:

```bash
swift build --configuration release --disable-automatic-resolution --product containertool
swift package --disable-automatic-resolution --swift-sdk "$SWIFT_SDK" \
  --configuration release \
  --allow-network-connections all build-container-image \
  --product "$PRODUCT" --repository "$IMAGE_REPOSITORY" --tag "$commit"
```

A local build may use a different tool from the published path; only the published path is release evidence, except when refused CI runners force publishing from the local build (the skill's rule 7). A plugin image's creation date is the epoch, so image age says nothing about freshness; probe a feature (`--help` listing a subcommand) instead.

## Publishing per commit

On a push to main, after every check, the image job builds the native image, checks it, and pushes that same image with one tag, the full commit SHA:

```
ghcr.io/<organization>/<organization>-<service>:<commit-sha>
```

The tag is written once and never moved: a re-run finds it and skips the push, so two commits never share an image and the image staging ran is the one production gets. There are no branch or environment tags; the platform is told which image to run on each deployment.

## The registry and retention

The workflow's own `GITHUB_TOKEN` pushes, with `permissions: packages: write` on the publishing job only. A package that already exists (created by a manual push under a personal token) does not trust any repository's token until its *Manage Actions access* setting grants the repository write (admin, for the cleanup workflow to delete versions). The setting is UI-only; the first pipeline push of every pre-existing package fails `permission_denied` until it is made.

Per-commit publishing fills a registry. Each repository carries [the weekly cleanup workflow](../assets/service-cleanup-images.yml) (`.github/workflows/cleanup-images.yml`, the package name filled in), keeping the newest 30 versions by default. It lives in each repository because schedules fire only in the repository that hosts them and deletion needs that repository's token. A SHA older than the window cannot be pulled again, so rollback targets are recent by construction, and recovery from a very old deploy is forward to a current SHA.

## Deploying to the platform

Each process is one platform application with the image as its source and auto-deploy off, so only the pipeline changes what runs. Every deployment, staging from main and production by hand, runs the ci repository's `deploy.yml` for an environment and a commit:

1. It resolves the commit to `<image-repository>:<commit-sha>@sha256:<digest>`; the platform shows the commit, and Docker pulls by digest.
2. For production, it requires a successful `Deploy staging` job in a push run of that commit, and reports whether the commit is still on its way to staging or never got there.
3. It checks that every ID in `application_ids` names an application before changing any, then, one at a time in the listed order, sets the image, requests a deployment titled with the short commit, and waits until the platform reports a deployment newer than the one before the request `done`. An error, a cancellation, or 15 minutes fails the run and leaves the remaining applications as they were.

A service with a worker lists both applications, the one that migrates first. The secrets are `DOKPLOY_URL` and `DOKPLOY_TOKEN`; the application IDs live in the callers. The platform API must be reachable from the runner: a public endpoint is one HTTPS call with an API key; a tailnet-only endpoint needs a tailnet-join step. The key can reconfigure every application: rotate it on any suspicion and keep the platform account behind a second factor.

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
- **Disable auto-deploy on every application and on the CA's resource**, so only the pipeline changes a service's image and nothing restarts or re-creates the CA.
- **Swarm's default stop grace period is ten seconds**, which kills a draining worker mid-Activity. Set the worker application's stop grace period longer than its longest Activity's drain.
- **A worker exits 0 on SIGTERM after draining.** A worker whose run loop throws after a graceful drain fails its `ServiceGroup` and exits 1, which cancels its other services and loses its last log lines; see the workflow skill's [worker reference](../../orchestrating-temporal-workflows/references/worker.md).
- **Do not link an application to a registry entry**: that designates a cluster registry and re-uploads every image on deploy, which a read-only pull token cannot do. Registry credentials entered once in the platform UI cover pulls for every application.
- **A crash-looping application can pin a stale spec**: after fixing configuration, stop it, then deploy.
- **A deployment reported `done` is not proof of health.** The platform finished rolling the container; whether the service answers is verified in the environment.

## Migrations

By default migrations run in the serving container at boot: the command is `serve --migrate-database`, and the process applies the list over a short-lived owner client (`PostgresClient.withClient` from swift-persistence-postgres) before the server binds (see *Migrations at boot* in the building skill's [composition reference](../../building-swift-services/references/composition.md#migrations-at-boot)). There is no migrate application and no pipeline ordering: a container cannot serve an unmigrated schema, because it migrates before it listens. Applying an already-applied list is a cheap no-op, so the flag stays on.

The accepted price: the owner pair sits in the serving container's environment for its lifetime. The serving process still connects only as its confined roles, so row-level security is unchanged, but a compromise of the container's environment yields the owner pair. With one shared owner across databases, that pair reaches every service's database, so give each database its own owner. Multiple replicas would race the apply at startup; when replicas arrive, the project records an advisory lock around the list or a `migrate` one-shot before the rollout. A failed migration crash-loops the new task while the rolling update keeps the old one serving.

The migration library refuses a list whose order differs from what a database already applied: it throws, it does not revert. Appending a migration, a role added later included, applies in place; inserting one before applied migrations means a fresh database (`docker compose down -v` locally), never an in-place `up`.

The old build briefly runs against the new schema during every deploy, and a rollback runs old code against a schema that moved forward, so migrations are expand/contract: add tables, nullable columns, and indexes freely; ship renames, drops, and tightened constraints in a later commit, once no deployed code references the old shape. A genuinely breaking migration is the rare deploy that is watched rather than unattended.
