---
name: delivering-swift-services
description: Defines reusable Swift library CI and delivers Swift services from a commit to a running process. Covers compiler compatibility, package resolution, formatting, service images, publishing, deployment, Compose, mounted secrets, mTLS certificates, migrations, and rollback. Use when creating or changing library CI or service delivery workflows, Containerfiles, image publishing, deployment, certificates, or stack startup.
---

# Delivering Swift services

How a service gets from a merged commit to a process that answers, and how the whole stack runs on one host: the pipeline that publishes and deploys, and the environment the deployed system runs in. Preserve every convention unless the user explicitly changes it; where the repository already has an established convention that differs, the repository wins for unrelated code.

For reusable library CI, read [library-ci.md](references/library-ci.md) and apply its gates.
The service deployment rules below apply to executable services. Repository `AGENTS.md`
profiles supply explicit compiler, platform, formatting, and coverage exceptions.

Designing the shape, building the modules, services, and HTTP surface, and running workflows are separate skills; this one publishes and runs what they produce.

Rules in this skill are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. Where a rule says *default* and names an alternative, that is a project choice: take the default unless the project's decision record says otherwise, and never switch it per file.

The references describe one worked default end to end: GitHub Actions, a Compose suite, a `step`-issued CA, Loki, a Dokploy-style platform. Every rule below leads with the principle that default satisfies, so another platform can satisfy it differently and still pass the gates.

## Load the references

Each topic has exactly one home. Every other skill says only that a value "comes from the environment" or that images "come from delivery".

| Task | Read |
| --- | --- |
| Reusable library CI, supported compilers, optional checks, library formatting, and repository exceptions | [library-ci.md](references/library-ci.md) |
| Service branches, CI, the tests job, the release image, per-commit publishing, the registry, deploy triggers, platform variable scopes, migrations in the pipeline, dependency updates, retention | [delivery.md](references/delivery.md) — the service pipeline |
| Images, the suite Compose file, Postgres instances, ports, secrets, the certificate volume, the gateway's address, log aggregation, verifying what a service receives | [environment.md](references/environment.md) — the only file that describes the running environment |

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **The commit is the version.** A service publishes an image per commit and carries no SemVer; the SHA is the deploy identifier and the rollback target. SemVer belongs to the packages consumers resolve by range.
2. **A pipeline that does less than it claims is worse than a red one.** Deploy steps are mandatory; a missing secret fails the run loudly. A green run is not proof a tag exists; check the manifest.
3. **Nothing is plaintext and nothing is published.** Every internal gRPC connection is mutually authenticated by a CA the stack controls; no internal port reaches a host interface; the gateway is reached only through its sidecar or the platform ingress.
4. **Key material is a file; configuration carries a path.** Secrets are mounted, never environment variables; each credential directory is enrolled before startup and maintained by its renewer.
5. **A container cannot serve an unmigrated schema.** Migrations run before the process binds, by default in the serving container at boot, and they are expand/contract because deploys roll back and schemas do not.
6. **Share the machinery, duplicate the declarations.** Logic that churns is centralized and versioned; a cron line, a retention count, a package name stays in each repository.
7. **Fail at `up`, not at the first request.** `${VAR:?message}` guards, secret source files, and health-gated `depends_on` make a misconfigured stack refuse to start.

## Rules

### Branches and CI

1. Two long-lived branches, two environments: every develop commit tests, publishes, and deploys to staging; every main commit tests and publishes, deploying to production once it exists. Promotion is a merge, never a steady-state cherry-pick.
2. Pull requests run the tests job regardless of target. Reuse the swiftlang test workflow pinned to a release tag's commit SHA, collapsed to the one toolchain, OS, and architecture production runs, with `swift test --disable-automatic-resolution` so the committed `Package.resolved` is the build.
3. Keep a static Linux SDK build in CI whenever the local image path is musl to catch SDK, C/C++, and dependency compatibility failures. Verify Foundation linking separately: a successful static build does not prove FoundationEssentials-only dependencies. Follow the linking gate in [delivery.md](references/delivery.md); document unavoidable upstream full-Foundation requirements while keeping our code on modern Essentials APIs.
4. Pin third-party actions and reusable workflows to reviewed commit SHAs with the release tag as a comment, or the branch and date when adopting functionality ahead of a release. Inspect nested workflow and script references before claiming the whole execution chain is pinned. Dependabot targets develop for services and main for libraries.
5. A service executable commits `Package.resolved` and re-resolves it when a dependency's tag moves; a library package never commits it and releases from semver labels. Move a tag only before anything depends on it, because SwiftPM's fingerprint store on every consumer's machine remembers the old commit.
6. When a private repository's arm runners are refused for billing, do not weaken the pipeline to pass: fund it, self-host, or publish through the local container-plugin build and a hand-triggered deploy until CI returns.

### Images and publishing

7. Publish two tags per commit: an immutable short SHA for forensics and rollback, and the moving branch tag the platform application tracks. Build the Containerfile natively for the deployment host's architecture, never under emulation.
8. One image per service, whether or not it has a worker; the worker application runs the same image at the same tag with `worker run` as its command.
9. Build from a two-stage `Containerfile`: resolve as its own layer, `swift build --configuration release --static-swift-stdlib`, then a minimal runtime image with an unprivileged user, `ca-certificates`, `tzdata`, and `SWIFT_BACKTRACE`. The local `Makefile` builds a static musl image through the container plugin; the two paths may differ because only one publishes.
10. Push with the workflow's own token and `packages: write`; grant a pre-existing package's Actions access to the repository before the first pipeline push. Prune each registry weekly to a recent window per repository.

### Deploying

11. Deploy is a single trigger-only step bound to plain secrets, SHA-pinned; rollback is pinning an older SHA on the platform application by hand, outside the pipeline.
12. One platform application per process, image-sourced and tracking the branch tag, so a rollout is a tag move and a rollback is a pin. Default: a Dokploy-style application whose `command` is `./<service> serve --migrate-database` (`command` replaces the entrypoint, so name the binary). Alternative: any platform that pins an image by SHA and rolls back by hand, such as a Kubernetes Deployment or a Fly app, with the same command, or with `migrate` as a pre-rollout job when the platform orders jobs.
13. Staging and production are two environments of one project. Shared values live in each environment's scope, referenced by every application as `${{environment.KEY}}`; the project scope stays empty; a per-tier secret never goes project-wide. Each environment owns its database instance, signing keypair, cache, and CA; platform services are shared with a namespace per environment.
14. Provisioning jobs are disposable one-shots with restart policy `none`, log-verified, deleted after use. A crash-looping application is stopped, then deployed, never deployed over.
15. Migrations run at boot in the serving container over a short-lived owner client. They are expand/contract: add tables, nullable columns, and indexes freely; ship renames, drops, and tightened constraints in a later commit once no deployed code references the old shape.

### The environment

16. The whole stack is declared in one place from published images, never built there, and a missing value stops it before anything starts; keep every environment concern in environment.md alone. Default: one `compose.yml`, a `.env.example` naming every variable, a git-ignored `.env` filling it, `${VAR:?message}` guards on required values, every anchor referenced, rendered with `docker compose config` before `up`. Alternative: a Helm chart or platform manifest with the same three properties (images only, every variable named with a required guard, rendered and reviewed before apply).
17. Publish nothing that nothing outside the stack calls; internal services are reached by name on a private network. Default: no `ports:` on Postgres, the cache, the workflow engine, the log store, or the gateway, and the gateway addressed through a tailnet sidecar or the platform ingress. Alternative: cluster-internal services with no node port or load balancer and the gateway behind an ingress, when the platform is Kubernetes.
18. Mount signing keys, TLS private keys, and CA/enrollment secrets as files with restrictive access. Applications see only their own credential directories; renewers write them, applications read them. Only the issuer mounts the JWT signing key; workers do not need user JWT keys.
19. Internal gRPC and Temporal connections require mTLS with explicit CA trust and verified server DNS names. Deploy Smallstep `step-ca` privately in the services’ Dokploy project, with separate environment trust; use scoped enrollment and persistent `step-cli` renewers publishing each workload’s files. Swift reloads leaves with `TimedCertificateReloader`; trust rotation uses overlap and transport reconstruction. Temporal credentials and reloaders are separate.
20. One database per service (one for a monolith), owned by that process's owner role, healthy before the process starts, migrated by the process itself. Default: one Postgres container per service in the suite with no init job, the image provisioning the database and owner. Alternative: one instance (a container or a managed cluster) with a database and an owner per service, the shape a small production usually runs; role names are cluster-wide, so each service's roles must be named distinctly there, and point-in-time recovery is per instance. The choice is per environment, weighed in the building skill's persistence reference under *Where a service's data lives*.
21. Every process ships its own structured logs to one aggregator, and dashboards are never on a host port. Default: in-process shipping (swift-log-loki to Loki, Grafana behind its own sidecar), no scraping agent. Alternative: stdout to the platform's collector when the platform provides one, keeping the service label and the identity metadata on every line.
22. Make first startup verifiable. Provision the CA, enroll initial workload credentials, start renewers, generate the JWT signing pair, and fill `.env` before applications start. With Compose, use `docker compose up -d`, then verify with `docker compose config <service>`, `pg_stat_activity` for the roles, and a request through the public hostname. Alternative: the platform's apply followed by the same three verifications.

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
- [ ] 4. docker compose up -d: initial enrollment supplies each workload’s leaf pair, renewers stay running, Postgres becomes healthy, services migrate and serve
- [ ] 5. Verify: pg_stat_activity shows the service and internal roles and never the owner; the sidecar registered; a request through the public hostname answers
```

## Completion gates

Do not call work complete until every applicable gate passes.

- Every commit to a deployment branch publishes one image per service with SHA and branch tags; the staging branch's deploy trigger rolls the service application, which is migrated before it serves (at boot, or by the migrate one-shot), and the worker application, which runs the same image with `worker run`.
- CI resolves from the committed `Package.resolved` and tests the architecture production runs; the static SDK build passes where the local image is musl; a missing deploy secret or variable fails the pipeline rather than skipping the deploy.
- Nothing is published that nothing outside the stack calls; `docker compose config` renders every required value; a stack missing a key or a secret file fails at `up`.
- Every gRPC server refuses a client without a certificate the stack's CA signed; every client verifies the server's name; every process missing its own certificate fails at startup naming the path; no plaintext mode exists.
- Only the authenticating service mounts the private signing key; no key is an environment variable; secrets never appear in logs.
- Logs carry a service label and searchable identifiers and reach the aggregator.
- Shared platform values live in each environment's scope and are referenced by every application; the project scope is empty; a promotion differs only by image tag.
- Rollback is possible to any SHA inside the retention window, by pinning the application, without a pipeline change.

If a gate requires an unresolved platform, billing, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
