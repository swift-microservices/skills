---
name: delivering-swift-services
description: Delivers Swift services from a commit to a running, mutually authenticated stack, and defines the standard CI profiles for Swift server libraries and deployable services. Covers the standard library and service CI and their recorded exceptions, the release image (Containerfile, static Linux SDK, or swift-container-plugin), per-commit publishing, staging and production deployment of serving and worker applications on a Dokploy-style platform, rollback, migrations in the pipeline, the Compose suite and its .env, mounted secrets and JWT signing keys, and mTLS certificates from a private CA such as Smallstep step-ca with enrollment and renewal. Use when creating or changing CI workflows, a Containerfile, image publishing, deployment, a compose.yaml or .env, certificates, step-ca, enrollment, renewal, or rotation, or when bootstrapping a stack or debugging its first start.
---

# Delivering Swift services

How a service gets from a merged commit to a process that answers, and how the whole stack runs: the CI of libraries and services, the pipeline that publishes and deploys, the running environment, and the certificates that secure it. Designing, building services, HTTP surfaces, libraries, and workflows are separate skills; this one validates, publishes, and runs what they produce.

Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these conventions. Preserve unrelated established code. An old workflow is not itself an exception.

Rules here are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. The image tool, the CA, where Postgres runs, and the library release mechanism are project choices, recorded once in `AGENTS.md`: each is a contract plus a worked example, never switched per file. The worked example is GitHub Actions, a Containerfile, a Compose suite, Smallstep `step-ca`, Loki, and a Dokploy-style platform; every rule leads with the principle, so another platform satisfies it differently and passes the same gates.

## Load the references

Each topic has exactly one home; other skills say only that a value "comes from the environment" or that images "come from delivery".

| Task | Read |
| --- | --- |
| CI for every reusable library used in server development, including the project's core, contract, and SDK packages: the standard shape, toolchains and raising the floor, formatter, headers, pins and releases, exceptions (database tests, Foundation linking, no tests, private repositories), recording them | [library-ci.md](references/library-ci.md) |
| CI for an executable service, monolith, gateway, or worker: the standard callers of the shared workflows, the deployed toolchain, locked tests, private dependencies, final-image checks, exceptions | [services-ci.md](references/services-ci.md) |
| The branch and its environments, the release image and its contract, local builds, publishing, the registry and retention, deploying to staging and production, rollback, platform traps, migrations | [delivery.md](references/delivery.md) |
| The running stack: the suite Compose file and `.env`, where Postgres runs, ports, secrets and JWT keys, the gateway's address, logs, verifying what a service receives | [environment.md](references/environment.md) |
| The CA contract and `step-ca`: initialization, provisioners, enrollment, renewal and publication, rekey, trust rotation, file ownership, Temporal TLS, the local development CA, verification | [certificates.md](references/certificates.md) |

The process side of what delivery supplies is another skill's: the serve and worker roots in the building-swift-services skill's [composition.md](../building-swift-services/references/composition.md) and their transport security in its [transport-security.md](../building-swift-services/references/transport-security.md), configuration keys in its [configuration.md](../building-swift-services/references/configuration.md), database roles and placement in its [migrations-and-rls.md](../building-swift-services/references/migrations-and-rls.md), and the worker and its Temporal credentials in the orchestrating-temporal-workflows skill's [worker.md](../orchestrating-temporal-workflows/references/worker.md).

Templates live in `assets/`; each reference names the ones it uses and whether to copy or execute them.

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **The commit is the version.** A service publishes an image per commit and carries no SemVer; the SHA is the deploy identifier and the rollback target. SemVer belongs to the packages consumers resolve by range.
2. **A pipeline that does less than it claims is worse than a red one.** Deployment is mandatory; a missing secret or application fails the run loudly, and a deployment waits until the platform reports it finished.
3. **Nothing is plaintext and nothing is published.** Every internal gRPC connection is mutually authenticated by a CA the stack controls, locally too; no internal port reaches a host interface; a client-facing listener is reached only through the edge, over TLS end to end.
4. **Key material is a file; configuration carries a path.** Signing keys, TLS keys and certificates, and enrollment tokens are mounted, never environment variables; database role passwords come from the environment, read as secrets. Renewers write credential directories; applications only read them.
5. **A container cannot serve an unmigrated schema.** Migrations run before the process binds, by default in the serving container at boot, and they are expand/contract because deploys roll back and schemas do not.
6. **Share the machinery, duplicate the declarations.** Logic that churns is centralized and versioned; a cron line, a retention count, a package name stays in each repository.
7. **Fail at `up`, not at the first request.** `${VAR:?message}` guards, secret source files, and health-gated `depends_on` make a misconfigured stack refuse to start.

## Rules

### Branches and CI

1. One long-lived branch, `main`. Every push validates, publishes the commit's image, and deploys it to staging; production deploys by hand, the latest main commit or a chosen one, only if staging ran it. Deployments are serialized per environment and never cancelled midway.
2. Every library follows the standard shape in [library-ci.md](references/library-ci.md) and every service the one in [services-ci.md](references/services-ci.md), reusing upstream workflows and the shared ci repository. A repository that differs records each exception in the `## CI` section of its `AGENTS.md`; an unrecorded difference is drift, not an exception. PRs never publish or deploy.
3. A successful static SDK build does not prove FoundationEssentials-only dependencies: inspect the executable as in [services-ci.md](references/services-ci.md#the-release-image-and-foundation) and document unavoidable upstream full-Foundation requirements while keeping owned code on Essentials APIs.
4. Pin every reusable workflow and action to its latest release's full commit with the release as a comment; only an upstream without releases is pinned to a `main` commit. Dependabot targets main.
5. A service executable commits its validated `Package.resolved`; a library never commits it and records API impact with SemVer labels. Released dependency tags never move: consumers remember their fingerprints.
6. The templates' Swift version (6.3) is the current floor, not a fixed rule. Raise it in libraries, services, and the ci repository together, with the checklist in [library-ci.md](references/library-ci.md#toolchains).
7. When a private repository's runners are refused for billing, do not weaken the pipeline to pass: fund it, self-host, narrow a private library as its recorded exception allows, or publish and deploy with the Makefile's `publish`, `stage`, and `deploy` until CI returns, production still only after staging.

### Images and publishing

8. Publish one tag per commit, the full commit SHA, written once and never moved; no branch or environment tags. Build natively for the deployment host's architecture, never under emulation.
9. One image per service; a worker application runs the same image with `worker run` as its command.
10. The image meets the contract in [delivery.md](references/delivery.md#the-release-image), whichever tool the project recorded: a locked release build, an unprivileged user, the backtracer and every resource bundle, and the image CI checked. Where a tool cannot meet a clause (`swift-container-plugin` images default to root), `AGENTS.md` records the exception and its compensating control.
11. Push with the workflow's own token and `packages: write` on the publishing job only; grant a pre-existing package's Actions access before the first pipeline push. Prune each registry weekly to a recent window per repository.

### Deploying

12. Deploy by digest: set each platform application's image to `:<commit-sha>@sha256:<digest>`, request a deployment, and wait until the platform reports it done, one application at a time in the listed order, the one that migrates first; a service with a worker lists both. Rollback is deploying an older commit the same way; nothing is rebuilt.
13. One platform application per process, image-sourced with auto-deploy off, so only the pipeline changes what runs. Default: a Dokploy-style application whose `command` names the binary's real path, `/app/<service> serve --migrate-database` (`command` replaces the entrypoint). Alternative: any platform that runs an image by digest and accepts an older one for rollback, such as a Kubernetes Deployment, with the same command or a `migrate` pre-rollout job.
14. Staging and production are two environments of one project. Shared values live in each environment's scope, referenced as `${{environment.KEY}}`; the project scope stays empty. Each environment owns its database, signing keypair, cache, and CA.
15. Provisioning jobs are disposable one-shots with restart policy `none`, log-verified, deleted after use. A crash-looping application is stopped, then deployed. A worker gets a stop grace period longer than its drain and exits 0 after draining.
16. Migrations follow *Migrations* in [delivery.md](references/delivery.md#migrations): at boot by default, expand/contract always.

### The environment

17. The whole stack is declared in one place from published images, never built there, and a missing value stops it before anything starts. Default: [environment.md](references/environment.md)'s Compose suite with `.env.example`, `${VAR:?message}` guards, every anchor referenced, rendered with `docker compose config` before `up`. Alternative: a Helm chart or platform manifest with the same three properties.
18. Publish nothing that nothing outside the stack calls. Default: no `ports:` on Postgres, the cache, the workflow engine, the log store, the CA, or any service. The edge is the project's choice meeting [environment.md](references/environment.md#public-ingress)'s contract — public TLS ends at the edge with strict origin verification, the proxy reaches the process over TLS it verifies, a client-facing listener needs no client certificate; default: Cloudflare (Full (Strict), gRPC enabled) in front of the platform's reverse proxy. Alternative: a tailnet sidecar.
19. Mount signing keys, TLS keys, and enrollment tokens as files with restrictive access. Each process sees only its own credential directories. Only the issuer mounts the JWT signing key; workers mount no JWT key.
20. Internal gRPC and Temporal connections require mTLS with explicit trust and verified server names; only a client-facing listener omits the client certificate, and no plaintext mode exists. The CA is the project's choice, private, one per environment, meeting the contract in [certificates.md](references/certificates.md); default: `step-ca` with one provisioner per workload, short-lived enrollment tokens, and a renewer per credential directory. Temporal credentials are separate or the process's, as recorded.
21. One database per service (one for a monolith) is an ownership rule: only that process migrates, reads, and writes its tables. Where it lives is the project's choice per environment, weighed in the building skill's persistence reference.
22. Every process ships its own structured logs to one aggregator, and dashboards are never on a host port. Default: in-process shipping to Loki, Grafana behind its own sidecar. Alternative: stdout to the platform's collector, keeping the service label and identity metadata.

## Workflows

Copy the checklist you need and check items off as you go.

```
Deliver a service:
- [ ] 1. The image build with the project's recorded tool (Containerfile and .dockerignore from assets, a static SDK build, or swift-container-plugin with its user exception decided); the Makefile and scripts/delivery.sh from assets, with .env's Dokploy settings
- [ ] 2. pull_request.yml, main.yml, deploy.yml, and cleanup-images.yml from the service templates, pinned by commit; application_ids in deploy order, the worker's included; Dependabot
- [ ] 3. With private dependencies: the ci repository's tests.yml and PACKAGES_TOKEN, passed to the image build too
- [ ] 4. The `## CI` section of AGENTS.md: the standard shape, then each exception with its reason
- [ ] 5. Platform application per process: image source, auto-deploy off, the binary's real path with serve --migrate-database or worker run, file mounts, environment-scope references, worker stop grace period
- [ ] 6. Repository secrets DOKPLOY_URL and DOKPLOY_TOKEN (and PACKAGES_TOKEN); a missing one fails the run
- [ ] 7. Push to main; confirm the :<commit-sha> tag exists and each staging application reported done, migrated before it served
- [ ] 8. Run Deploy production for that commit; confirm production reported done
```

```
Bring CI to the standard:
- [ ] 1. Read the repository's AGENTS.md: its toolchain, products, and recorded exceptions
- [ ] 2. Copy the library or service templates (a service's Makefile and scripts/delivery.sh too); keep only differences an exception in library-ci.md or services-ci.md allows
- [ ] 3. Pin every reusable workflow and action to its latest release's commit
- [ ] 4. Write the `## CI` section: the standard, then each exception's reason, coverage, and revisit condition
- [ ] 5. actionlint and yamllint pass; report what only GitHub can run
```

```
Bootstrap the environment:
- [ ] 1. CA: offline root and intermediate, ca.json with one JWK provisioner per workload (fixed subject and SANs, bounded durations), PKI volume primed, CA healthy with no host port
- [ ] 2. Enroll: permission-init, one offline-minted short-lived token per credential directory, the enrollment one-shot verified, tokens and one-shots removed
- [ ] 3. Renewers: one per credential directory, healthy, the only writers of what applications read
- [ ] 4. JWT keys: generate-jwt-keys.sh into a git-ignored 0700 directory; only the issuer mounts the private key
- [ ] 5. .env from .env.example, every required value filled, images pinned to published tags
- [ ] 6. docker compose config renders every service: anchors referenced, guards satisfied, no ports on internal services
- [ ] 7. docker compose up -d: Postgres healthy, services migrate then serve, workers poll
- [ ] 8. Verify: pg_stat_activity shows the service, internal, and worker roles and never the owner; certificate-verify-peer.sh passes on each internal listener; a request through the public hostname answers
```

## Completion gates

Apply the gates relevant to the requested scope. A CI change reports the validation run and the checks left unexecuted; it does not require publication or deployment.

- Every push to main publishes one checked image per service, tagged once with the full commit SHA, and deploys it to staging by digest: the service application, migrated before it serves, then the worker application on the same image with `worker run`. Production deploys only a commit staging ran.
- Each repository's CI is the standard shape plus the exceptions its `AGENTS.md` records. A service resolves from the committed `Package.resolved` and tests the toolchain and architecture production runs; a missing deploy secret fails the pipeline.
- Nothing is published that nothing outside the stack calls; `docker compose config` renders every required value; a stack missing a key or a secret file fails at `up`.
- Every internal gRPC listener refuses a client without a certificate the stack's CA signed; a client-facing listener serves TLS the edge proxy verifies; every client verifies the server's name; a process missing its certificate fails at startup naming the path; no plaintext mode exists; renewers write and applications only read.
- Only the authenticating service mounts the private signing key; no key is an environment variable; secrets never appear in logs.
- Logs carry a service label and searchable identifiers and reach the aggregator.
- Shared platform values live in each environment's scope; the project scope is empty; staging and production differ only in the commit they run.
- Rollback is possible to any commit inside the retention window, by deploying it to production, without a rebuild or a pipeline change.

If a gate requires an unresolved platform, billing, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
