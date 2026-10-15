---
name: delivering-swift-services
description: Delivers Swift services from a commit to a running, mutually authenticated stack, and defines the standard CI profiles for Swift server libraries and deployable services. Covers library and service CI, compiler compatibility, locked resolution, formatting, the release image (Containerfile, static Linux SDK, or swift-container-plugin), per-commit publishing, deployment of serving and worker applications on a Dokploy-style platform, rollback, migrations in the pipeline, the Compose suite and its .env, mounted secrets and JWT signing keys, and mTLS certificates from a private CA such as Smallstep step-ca with enrollment and renewal. Use when creating or changing CI workflows, a Containerfile, image publishing, deployment, a compose.yaml or .env, certificates, step-ca, enrollment, renewal, or rotation, or when bootstrapping a stack or debugging its first start.
---

# Delivering Swift services

How a service gets from a merged commit to a process that answers, and how the whole stack runs: the CI of libraries and services, the pipeline that publishes and deploys, the running environment, and the certificates that secure it. Designing, building services, HTTP surfaces, libraries, and workflows are separate skills; this one validates, publishes, and runs what they produce.

Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these conventions. Preserve unrelated established code. An old workflow is not itself an exception.

Rules here are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. The image tool, the CA, where Postgres runs, and the library release mechanism are project choices, recorded once in `AGENTS.md`: each is a contract plus a worked example, never switched per file. The worked example is GitHub Actions, a Containerfile, a Compose suite, Smallstep `step-ca`, Loki, and a Dokploy-style platform; every rule leads with the principle, so another platform satisfies it differently and passes the same gates.

## Load the references

Each topic has exactly one home; other skills say only that a value "comes from the environment" or that images "come from delivery".

| Task | Read |
| --- | --- |
| CI for every reusable library used in server development, including the project's core, contract, and SDK packages: compilers, optional checks, formatter, headers, dependency policy, capability exceptions, private organization libraries | [library-ci.md](references/library-ci.md) |
| CI for an executable service, monolith, gateway, or worker: deployed compiler and architecture, locked tests, static SDK, final-image validation | [services-ci.md](references/services-ci.md) |
| Branches, the release image and its contract, local builds, publishing, the registry and retention, deploying serving and worker applications, platform traps, migrations | [delivery.md](references/delivery.md) |
| The running stack: the suite Compose file and `.env`, where Postgres runs, ports, secrets and JWT keys, the gateway's address, logs, verifying what a service receives | [environment.md](references/environment.md) |
| The CA contract and `step-ca`: initialization, provisioners, enrollment, renewal and publication, rekey, trust rotation, file ownership, Temporal TLS, the local development CA, verification | [certificates.md](references/certificates.md) |

The process side of what delivery supplies is another skill's: the serve and worker roots and their transport security in the building-swift-services skill's [composition.md](../building-swift-services/references/composition.md), configuration keys in its [configuration.md](../building-swift-services/references/configuration.md), database roles and placement in its [persistence.md](../building-swift-services/references/persistence.md), and the worker and its Temporal credentials in the orchestrating-temporal-workflows skill's [worker.md](../orchestrating-temporal-workflows/references/worker.md).

Templates live in `assets/`; each reference names the ones it uses and whether to copy or execute them.

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **The commit is the version.** A service publishes an image per commit and carries no SemVer; the SHA is the deploy identifier and the rollback target. SemVer belongs to the packages consumers resolve by range.
2. **A pipeline that does less than it claims is worse than a red one.** Deploy steps are mandatory; a missing secret fails the run loudly. A green run is not proof a tag exists; check the manifest.
3. **Nothing is plaintext and nothing is published.** Every internal gRPC connection is mutually authenticated by a CA the stack controls, locally too; no internal port reaches a host interface; a client-facing listener is reached only through the edge, over TLS end to end.
4. **Key material is a file; configuration carries a path.** Signing keys, TLS keys and certificates, and enrollment tokens are mounted, never environment variables; database role passwords come from the environment, read as secrets. Renewers write credential directories; applications only read them.
5. **A container cannot serve an unmigrated schema.** Migrations run before the process binds, by default in the serving container at boot, and they are expand/contract because deploys roll back and schemas do not.
6. **Share the machinery, duplicate the declarations.** Logic that churns is centralized and versioned; a cron line, a retention count, a package name stays in each repository.
7. **Fail at `up`, not at the first request.** `${VAR:?message}` guards, secret source files, and health-gated `depends_on` make a misconfigured stack refuse to start.

## Rules

### Branches and CI

1. Two long-lived branches, two environments: develop validates and deploys successful candidates to staging; main validates and publishes them, deploying to production once it exists. Serialize rollouts per branch; superseded pending runs need not deploy every intermediate commit. Promotion is a merge, never a steady-state cherry-pick.
2. PRs and deployment-branch pushes follow [services-ci.md](references/services-ci.md): the deployed platform, source and workflow checks, locked focused tests, a static SDK build where the image path uses one, and actual final-image validation. PRs never publish or deploy; publication waits for the required checks.
3. A successful static SDK build does not prove FoundationEssentials-only dependencies: inspect the executable as in [services-ci.md](references/services-ci.md#release-image-and-foundation) and document unavoidable upstream full-Foundation requirements while keeping owned code on Essentials APIs.
4. Pin service actions and reusable workflows to reviewed commit SHAs with the release tag as a comment. Library references follow their [CI profile](references/library-ci.md#dependency-resolution-and-workflow-references), which may prefer `@main`. Inspect nested references before claiming immutability. Dependabot targets develop for services and main for libraries.
5. A service executable commits its validated `Package.resolved`; a library never commits it and records API impact with SemVer labels. Released dependency tags never move: consumers remember their fingerprints.
6. When a private repository's runners are refused for billing, do not weaken the pipeline to pass: fund it, self-host, or publish through the local image build and a hand-triggered deploy until CI returns.

### Images and publishing

7. Publish two tags per commit: an immutable short SHA for forensics and rollback, and the moving branch tag the platform application tracks. Build natively for the deployment host's architecture, never under emulation.
8. One image per service; a worker application runs the same image at the same tag with `worker run` as its command.
9. The image meets the contract in [delivery.md](references/delivery.md#the-release-image), whichever tool the project recorded: a locked release build, an unprivileged fixed numeric user, the backtracer and every resource bundle, and the image CI validated. Where a tool cannot meet a clause (`swift-container-plugin` images default to root), `AGENTS.md` records the exception and its compensating control.
10. Push with the workflow's own token and `packages: write` on the publishing job only; grant a pre-existing package's Actions access before the first pipeline push. Prune each registry weekly to a recent window per repository.

### Deploying

11. Deploy is a trigger-only step per application bound to plain secrets, SHA-pinned; a service with a worker deploys both applications. Rollback is pinning an older SHA on the platform application by hand, outside the pipeline.
12. One platform application per process, image-sourced and tracking the branch tag. Default: a Dokploy-style application whose `command` names the binary's real path, `/app/<service> serve --migrate-database` (`command` replaces the entrypoint). Alternative: any platform that pins an image by SHA and rolls back by hand, such as a Kubernetes Deployment, with the same command or a `migrate` pre-rollout job.
13. Staging and production are two environments of one project. Shared values live in each environment's scope, referenced as `${{environment.KEY}}`; the project scope stays empty. Each environment owns its database, signing keypair, cache, and CA.
14. Provisioning jobs are disposable one-shots with restart policy `none`, log-verified, deleted after use. A crash-looping application is stopped, then deployed. A worker gets a stop grace period longer than its drain and exits 0 after draining.
15. Migrations follow *Migrations* in [delivery.md](references/delivery.md#migrations): at boot by default, expand/contract always.

### The environment

16. The whole stack is declared in one place from published images, never built there, and a missing value stops it before anything starts. Default: [environment.md](references/environment.md)'s Compose suite with `.env.example`, `${VAR:?message}` guards, every anchor referenced, rendered with `docker compose config` before `up`. Alternative: a Helm chart or platform manifest with the same three properties.
17. Publish nothing that nothing outside the stack calls. Default: no `ports:` on Postgres, the cache, the workflow engine, the log store, the CA, or any service. The edge is the project's choice meeting [environment.md](references/environment.md#public-ingress)'s contract — public TLS ends at the edge with strict origin verification, the proxy reaches the process over TLS it verifies, a client-facing listener needs no client certificate; default: Cloudflare (Full (Strict), gRPC enabled) in front of the platform's reverse proxy. Alternative: a tailnet sidecar.
18. Mount signing keys, TLS keys, and enrollment tokens as files with restrictive access. Each process sees only its own credential directories. Only the issuer mounts the JWT signing key; workers mount no JWT key.
19. Internal gRPC and Temporal connections require mTLS with explicit trust and verified server names; only a client-facing listener omits the client certificate, and no plaintext mode exists. The CA is the project's choice, private, one per environment, meeting the contract in [certificates.md](references/certificates.md); default: `step-ca` with one provisioner per workload, short-lived enrollment tokens, and a renewer per credential directory. Temporal credentials are separate or the process's, as recorded.
20. One database per service (one for a monolith) is an ownership rule: only that process migrates, reads, and writes its tables. Where it lives is the project's choice per environment, weighed in the building skill's persistence reference.
21. Every process ships its own structured logs to one aggregator, and dashboards are never on a host port. Default: in-process shipping to Loki, Grafana behind its own sidecar. Alternative: stdout to the platform's collector, keeping the service label and identity metadata.

## Workflows

Copy the checklist you need and check items off as you go.

```
Deliver a service:
- [ ] 1. The image build with the project's recorded tool (Containerfile and .dockerignore from assets, a static SDK build, or swift-container-plugin with its user exception decided); a local Makefile build
- [ ] 2. PR/develop/main workflows over reusable checks.yml and image.yml: checks → image smoke validation → publish → deploy; worker: true and the worker deploy step when a worker exists
- [ ] 3. Static Linux SDK job beside the tests when the image path uses the static SDK; weekly cleanup and Dependabot
- [ ] 4. Platform application per process: image source, branch tag, the binary's real path with serve --migrate-database or worker run, file mounts, environment-scope references, worker stop grace period
- [ ] 5. Deploy secrets set on the repository, worker application ids included; a missing one fails the run
- [ ] 6. Push to develop; confirm the SHA and branch tags exist; confirm each application rolled and migrated before it served
- [ ] 7. Promote by merging develop into main; confirm the :main tag exists before debugging a deploy
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

- Successful deployment candidates publish one validated image per service with SHA and branch tags; the deploy trigger rolls the service application, migrated before it serves, and the worker application on the same image with `worker run`.
- CI resolves from the committed `Package.resolved` and tests the architecture production runs; the static SDK build passes where the image path uses it; a missing deploy secret fails the pipeline.
- Nothing is published that nothing outside the stack calls; `docker compose config` renders every required value; a stack missing a key or a secret file fails at `up`.
- Every internal gRPC listener refuses a client without a certificate the stack's CA signed; a client-facing listener serves TLS the edge proxy verifies; every client verifies the server's name; a process missing its certificate fails at startup naming the path; no plaintext mode exists; renewers write and applications only read.
- Only the authenticating service mounts the private signing key; no key is an environment variable; secrets never appear in logs.
- Logs carry a service label and searchable identifiers and reach the aggregator.
- Shared platform values live in each environment's scope; the project scope is empty; a promotion differs only by image tag.
- Rollback is possible to any SHA inside the retention window, by pinning the application, without a pipeline change.

If a gate requires an unresolved platform, billing, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
