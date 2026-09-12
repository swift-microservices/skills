---
name: delivering-swift-services
description: Delivers Swift services from a commit to a running process: the Containerfile and the static-SDK image, per-commit SHA and branch tags, the branch-per-environment CI on GitHub Actions with mandatory deploy triggers, the platform's applications and variable scopes, the suite Compose file with .env guards, file-mounted secrets, the CA-issued mTLS certificate volume, the gateway's address, log aggregation, migrations at boot, rollback, and registry retention. Use when writing or debugging a Containerfile, Makefile, compose.yml, .env, GitHub Actions workflow, deploy step, image tag, registry cleanup, certificate or CA setup, platform application configuration, or the first start of a stack.
---

# Delivering Swift services

How a service gets from a merged commit to a process that answers, and how the whole stack runs on one host: the pipeline that publishes and deploys, and the environment the deployed system runs in. Preserve every convention unless the user explicitly changes it; where the repository already has an established convention that differs, the repository wins for unrelated code.

Designing the shape, building the modules, services, and HTTP surface, and running workflows are separate skills; this one publishes and runs what they produce.

## Load the references

Each topic has exactly one home. Every other skill says only that a value "comes from the environment" or that images "come from delivery".

| Task | Read |
| --- | --- |
| Branches, CI, the tests job, the release image, per-commit publishing, the registry, deploy triggers, platform variable scopes, migrations in the pipeline, dependency updates, retention | [delivery.md](references/delivery.md) — the only file that describes the pipeline |
| Images, the suite Compose file, Postgres instances, ports, secrets, the certificate volume, the gateway's address, log aggregation, verifying what a service receives | [environment.md](references/environment.md) — the only file that describes the running environment |

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **The commit is the version.** A service publishes an image per commit and carries no SemVer; the SHA is the deploy identifier and the rollback target. SemVer belongs to the packages consumers resolve by range.
2. **A pipeline that does less than it claims is worse than a red one.** Deploy steps are mandatory; a missing secret fails the run loudly. A green run is not proof a tag exists; check the manifest.
3. **Nothing is plaintext and nothing is published.** Every internal connection is mutually authenticated by a CA the stack issues itself; no internal port reaches a host interface; the gateway is reached only through its sidecar or the platform ingress.
4. **Key material is a file; configuration carries a path.** Secrets are mounted, never environment variables; the certificate volume is issued by the stack on first start and reaches only the stack.
5. **A container cannot serve an unmigrated schema.** Migrations run in the serving container at boot, and they are expand/contract because deploys roll back and schemas do not.
6. **Share the machinery, duplicate the declarations.** Logic that churns is centralized and versioned; a cron line, a retention count, a package name stays in each repository.
7. **Fail at `up`, not at the first request.** `${VAR:?message}` guards, secret source files, and health-gated `depends_on` make a misconfigured stack refuse to start.

## Rules

### Branches and CI

1. Two long-lived branches, two environments: every develop commit tests, publishes, and deploys to staging; every main commit tests and publishes, deploying to production once it exists. Promotion is a merge, never a steady-state cherry-pick.
2. Pull requests run the tests job regardless of target. Reuse the swiftlang test workflow pinned by tag, collapsed to the one toolchain, OS, and architecture production runs, with `swift test --disable-automatic-resolution` so the committed `Package.resolved` is the build.
3. Keep a static Linux SDK build in CI whenever the local image path is musl: that job is where full-Foundation imports and a missing `NIOFoundationCompat` link surface.
4. Pin third-party actions to commit SHAs with a version comment; let dependabot move them, targeting develop for both the Swift and Actions ecosystems.
5. A service executable commits `Package.resolved` and re-resolves it when a dependency's tag moves; a library package never commits it and releases from semver labels. Move a tag only before anything depends on it, because SwiftPM's fingerprint store on every consumer's machine remembers the old commit.
6. When a private repository's arm runners are refused for billing, do not weaken the pipeline to pass: fund it, self-host, or publish through the local container-plugin build and a hand-triggered deploy until CI returns.

### Images and publishing

7. Publish two tags per commit: an immutable short SHA for forensics and rollback, and the moving branch tag the platform application tracks. Build the Containerfile natively for the deployment host's architecture, never under emulation.
8. One image per service, whether or not it has a worker; the worker application runs the same image at the same tag with `worker run` as its command.
9. Build from a two-stage `Containerfile`: resolve as its own layer, `swift build --configuration release --static-swift-stdlib`, then a minimal runtime image with an unprivileged user, `ca-certificates`, `tzdata`, and `SWIFT_BACKTRACE`. The local `Makefile` builds a static musl image through the container plugin; the two paths may differ because only one publishes.
10. Push with the workflow's own token and `packages: write`; grant a pre-existing package's Actions access to the repository before the first pipeline push. Prune each registry weekly to a recent window per repository.

### Deploying

11. Deploy is a single trigger-only step bound to plain secrets, SHA-pinned; rollback is pinning an older SHA on the platform application by hand, outside the pipeline.
12. One platform application per process, image-sourced, tracking the branch tag, with `./<service> serve --migrate-database` as its command; `command` replaces the entrypoint, so name the binary.
13. Staging and production are two environments of one project. Shared values live in each environment's scope, referenced by every application as `${{environment.KEY}}`; the project scope stays empty; a per-tier secret never goes project-wide. Each environment owns its database instance, signing keypair, cache, and CA; platform services are shared with a namespace per environment.
14. Provisioning jobs are disposable one-shots with restart policy `none`, log-verified, deleted after use. A crash-looping application is stopped, then deployed, never deployed over.
15. Migrations run at boot in the serving container over a short-lived owner client. They are expand/contract: add tables, nullable columns, and indexes freely; ship renames, drops, and tightened constraints in a later commit once no deployed code references the old shape.

### The environment

16. Keep every environment concern in environment.md alone. One `compose.yml` runs the whole stack from published images and never builds them; a `.env.example` names every variable and a git-ignored `.env` fills it; required values are `${VAR:?message}` guards; every anchor is referenced; render with `docker compose config` before `up`.
17. Publish nothing that nothing outside the stack calls: no `ports:` on Postgres, the cache, the workflow engine, the log store, or the gateway. The gateway gets its address from a tailnet sidecar or the platform ingress; internal services are reached by name.
18. Mount secrets as files and configure them by path. The signing pair is the only secret file: only the authenticating service mounts the private key, every verifying service mounts the public key, a worker mounts neither.
19. The certificate volume is issued by a one-shot `step` service on the first `up`: one root CA, one leaf per process with `spiffe://<project>/<process>` as a URI SAN beside its DNS names, mounted read-only by `subpath` so each process sees its own leaf and the CA. There is no plaintext mode and no mode variable. A process's certificate is its only credential; there is no service token and no `service` role. Rotation is reissue plus `up --force-recreate`.
20. One Postgres instance per service in the suite, healthy before the service starts, with no init job: the image provisions the database and owner, and the service migrates at boot. A deployment may consolidate to one shared instance with a database per service.
21. Every process ships its own logs in-process to the aggregator; there is no scraping agent. Dashboards sit behind their own sidecar with no host port.
22. The first start is not staged: generate the signing pair, fill `.env`, `docker compose up -d`. Verify with `docker compose config <service>`, `pg_stat_activity` for the roles, and a request through the public hostname.

## Workflows

Copy the checklist you need and check items off as you go.

```
Deliver a service:
- [ ] 1. Containerfile and .dockerignore per delivery.md; Makefile with the container-plugin build for local images
- [ ] 2. pull_request.yml (tests), develop.yml (tests → publish → deploy staging), main.yml (tests → publish → deploy production), cleanup-images.yml, dependabot.yml targeting develop
- [ ] 3. Static Linux SDK job beside the tests job when the local image path is musl
- [ ] 4. Platform application per process: image source, branch tag, ./<service> serve --migrate-database, file mounts for keys and certificates, environment-scope references
- [ ] 5. Deploy secrets set on the repository; a missing one must fail the run, not skip the deploy
- [ ] 6. Push to develop; confirm the SHA and branch tags exist in the registry; confirm the application rolled and migrated before it served
- [ ] 7. Promote by merging develop into main; confirm the :main tag exists before debugging a deploy
```

```
First start of a stack:
- [ ] 1. compose.yml from published images, .env.example copied to .env, every required value filled
- [ ] 2. Signing pair generated into ./secrets with 0700/umask 077; the directory git-ignored
- [ ] 3. docker compose config renders every service; every anchor referenced; every ${VAR:?} satisfied
- [ ] 4. docker compose up -d: tls-init issues the CA and leaves, Postgres instances become healthy, services migrate at boot and serve
- [ ] 5. Verify: pg_stat_activity shows the service and internal roles and never the owner; the sidecar registered; a request through the public hostname answers
```

## Completion gates

Do not call work complete until every applicable gate passes.

- Every commit to a deployment branch publishes one image per service with SHA and branch tags; the staging branch's deploy trigger rolls the service application, which migrates at boot before it serves, and the worker application, which runs the same image with `worker run`.
- CI resolves from the committed `Package.resolved` and tests the architecture production runs; the static SDK build passes where the local image is musl; a missing deploy secret or variable fails the pipeline rather than skipping the deploy.
- Nothing is published that nothing outside the stack calls; `docker compose config` renders every required value; a stack missing a key or a secret file fails at `up`.
- Every gRPC server refuses a client without a certificate the stack's CA signed; every client verifies the server's name; every process missing its own certificate fails at startup naming the path; every leaf carries its `spiffe://` URI SAN; no plaintext mode exists.
- Only the authenticating service mounts the private signing key; no key is an environment variable; secrets never appear in logs.
- Logs carry a service label and searchable identifiers and reach the aggregator.
- Shared platform values live in each environment's scope and are referenced by every application; the project scope is empty; a promotion differs only by image tag.
- Rollback is possible to any SHA inside the retention window, by pinning the application, without a pipeline change.

If a gate requires an unresolved platform, billing, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
