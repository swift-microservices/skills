# Bootstrap: a complete stack from nothing

Use this reference when a project starts from an empty repository and the whole stack has to exist: packages, CI, images, certificates, keys, a database, and a first running request. It orders the work and routes each step to the skill and reference that own it; it restates none of them. Copy the variant the decision record names and check items off as each gate passes.

## Contents

- [How to read a step](#how-to-read-a-step)
- [Modular monolith](#modular-monolith)
- [Microservices](#microservices)
- [Verification](#verification)
- [What not to do](#what-not-to-do)

## How to read a step

Each step names what to produce, the owner to load before producing it, and the gate that proves it is done. Do not start a step before the previous gate passes: a later step builds on an earlier one's tag, schema, or certificate. Build one vertical journey first; add the next capability only after the first is verified, and scaffold no unused module, service, or infrastructure in advance.

## Modular monolith

One package, one executable, every module inside.

```
Bootstrap a modular monolith:
- [ ] 1. Decision record
- [ ] 2. The package and its shared targets
- [ ] 3. Modules, vertically
- [ ] 4. The HTTP surface, the gRPC surface, or both
- [ ] 5. The executable root, the roles, and the migrations
- [ ] 6. Tests
- [ ] 7. Service CI and the image
- [ ] 8. The environment
- [ ] 9. First start and verification
```

1. **Decision record.** Produce: shape `monolith`, transport, modules and the tables each owns, callers, where identity is verified, Postgres placement, tenant isolation, split candidates. Owner: [shapes.md](shapes.md#the-decision-record). Gate: every module owns one capability; the dependency graph has no cycle; the record names no split candidate without a concrete reason.
2. **The package and its shared targets.** Produce: `<organization>-<project>` from `swift package init --type executable`, the shared settings array on every target, and the organization layer in-package — `<Project>Authentication`, `<Project>Persistence`, `<Project>Testing` — until a second package needs it, then a tagged `<project>-core`. With gRPC, the `.proto` files and generator configuration live in the package under the same rule. Owner: [service-package.md](../../building-swift-services/references/service-package.md), [organization-layer.md](../../building-swift-server-libraries/references/organization-layer.md), [grpc-and-protos.md](../../building-swift-services/references/grpc-and-protos.md#canonical-proto-package), [swift-settings.md](../../writing-swift-server-code/references/swift-settings.md). Gate: `swift build` succeeds with the empty targets; no `.package(path:)`.
3. **Modules, vertically.** Produce: per module in dependency order, `<Module>Core` with its use cases and their tests, then `<Module>Postgres` with scopes, statements, repositories, policies, and migration types. Owner: the building-swift-services skill's module checklist, [core.md](../../building-swift-services/references/core.md), [persistence.md](../../building-swift-services/references/persistence.md). Gate: each `<Module>CoreTests` passes over `MockDatabase`; no module imports another module's targets.
4. **The HTTP surface, the gRPC surface, or both.** Produce: `<Project>HTTP` contexts and errors and a `<Module>HTTP` per module, and/or a `<Module>GRPC` per module with its interceptors. Owner: [surface.md](../../building-swift-http-surfaces/references/surface.md), [grpc-and-protos.md](../../building-swift-services/references/grpc-and-protos.md). Gate: every route or RPC calls a use-case protocol; no business decision lives in a transport.
5. **The executable root, the roles, and the migrations.** Produce: `Serve.swift` composing every module, `Database/Migrations.swift` listing every migration explicitly — usually the role migrations first, then each module's tables and policies in dependency order — and `serve --migrate-database`. Owner: [composition.md](../../building-swift-services/references/composition.md), [persistence.md](../../building-swift-services/references/persistence.md#the-roles), [configuration.md](../../building-swift-services/references/configuration.md). Gate: the process migrates as the owner and serves as `<project>_service` (and `<project>_internal` with tenant tables).
6. **Tests.** Produce: use-case tests per module, router tests over mocked use-case protocols for tiers and error mapping, and one live loopback suite for token verification, propagation, and wiring (server TLS and a bearer on a client-facing listener, mTLS on an internal one). Owner: [testing.md](../../building-swift-services/references/testing.md), [surface.md](../../building-swift-http-surfaces/references/surface.md#tests). Gate: `swift test` passes.
7. **Service CI and the image.** Produce: the pull-request, develop, and main workflows and the image build with the project's recorded tool. Owner: [services-ci.md](../../delivering-swift-services/references/services-ci.md), [delivery.md](../../delivering-swift-services/references/delivery.md). Gate: checks pass on a pull request; a push publishes the SHA and branch tags.
8. **The environment.** Produce: the CA, each workload's enrollment and renewer, the JWT signing pair, Postgres with the role secrets, and the Compose file. Owner: [certificates.md](../../delivering-swift-services/references/certificates.md), [environment.md](../../delivering-swift-services/references/environment.md). Gate: `docker compose config` renders every service with every required value set.
9. **First start and verification.** Run the stack and pass [Verification](#verification).

A Temporal worker, when a module needs one, is added after step 5 with the orchestrating-temporal-workflows skill ([worker.md](../../orchestrating-temporal-workflows/references/worker.md)). A client SDK for the apps, when they consume the OpenAPI document, follows step 4 ([client-sdk.md](../../building-swift-http-surfaces/references/client-sdk.md)).

## Microservices

One package per service, shared code in tagged packages, a gateway in front.

```
Bootstrap microservices:
- [ ] 1. Decision record
- [ ] 2. <project>-protos and <project>-core, tagged
- [ ] 3. Each service, owner first
- [ ] 4. The gateway
- [ ] 5. The client SDK
- [ ] 6. Library CI and service CI
- [ ] 7. The environment
- [ ] 8. First start and verification
```

1. **Decision record.** Produce: the record, the ownership table, the interaction map, and a concrete reason for every remote boundary. Owner: [shapes.md](shapes.md#the-decision-record), [distributed-systems.md](distributed-systems.md). Gate: each service names its reason to run alone; every cross-service interaction has a consistency record.
2. **`<project>-protos` and `<project>-core`, tagged.** Produce: the canonical protos with `<Entity>Service` and, where another process calls in, `<Entity>InternalService`; the organization layer over the swift-microservices packages. Owner: the building-swift-server-libraries skill, [organization-layer.md](../../building-swift-server-libraries/references/organization-layer.md), [grpc-and-protos.md](../../building-swift-services/references/grpc-and-protos.md#canonical-proto-package). Gate: both build and carry a SemVer tag; consumers can pin them by URL and tag.
3. **Each service, owner first.** Produce: per service, Core with tests, Postgres with its role migrations, `<Service>GRPC`, the root, then its consumers' gRPC client adapters behind the ports in their own Core. Owner: the building-swift-services skill, [composition.md](../../building-swift-services/references/composition.md#transport-security-factories), [testing.md](../../building-swift-services/references/testing.md). Gate: `swift build` and `swift test` pass in each package; the live loopback mTLS suite proves receiver verification and descriptor-scoped propagation.
4. **The gateway.** Produce: `<organization>-api` with `API` and `<Project>`, one mTLS client per upstream. Owner: [gateway.md](../../building-swift-http-surfaces/references/gateway.md), [surface.md](../../building-swift-http-surfaces/references/surface.md). Gate: `APITests` pass; no route reaches an internal descriptor.
5. **The client SDK.** Produce: `<organization>-sdk` generated from the gateway's OpenAPI document. Owner: [client-sdk.md](../../building-swift-http-surfaces/references/client-sdk.md). Gate: it builds against the tagged document and is tagged itself.
6. **Library CI and service CI.** Produce: the library profile for `<project>-protos`, `<project>-core`, and the SDK; the service profile and image for every service and the gateway. Owner: [library-ci.md](../../delivering-swift-services/references/library-ci.md), [services-ci.md](../../delivering-swift-services/references/services-ci.md), [delivery.md](../../delivering-swift-services/references/delivery.md). Gate: checks pass on a pull request in every repository; each executable publishes SHA and branch tags.
7. **The environment.** Produce: the CA, a leaf and renewer per workload, the JWT signing pair mounted only into the authenticating service and its public key into every verifier, a database per service at the recorded placement, role secrets, and the suite Compose file. Owner: [certificates.md](../../delivering-swift-services/references/certificates.md), [environment.md](../../delivering-swift-services/references/environment.md). Gate: `docker compose config` renders; no internal port is published.
8. **First start and verification.** Run the stack and pass [Verification](#verification).

Workers follow step 3 for the services that need them ([worker.md](../../orchestrating-temporal-workflows/references/worker.md)).

## Verification

The stack is up when every item holds; the first start checklist in the delivering-swift-services skill runs them.

- Every process migrated before it served, and `pg_stat_activity` shows the service, internal, and worker roles, never the owner.
- A request through the public hostname reaches a use case and answers; an anonymous request to a requiring route answers 401; a non-administrator on an administrative route answers 403.
- One user cannot read or change another user's rows through any route.
- In microservices, a service called with a forged or expired token refuses it; an internal port refuses a peer without a certificate from the stack's CA.
- A renewed leaf is used on the next handshake without a restart.
- The first journey works end to end, including one dependency failure and one retried request that does not duplicate its effect.

## What not to do

- Do not create `<project>-core` or `<project>-protos` for a one-package monolith; the in-package targets move when a second package needs them.
- Do not build a gateway, a broker, or a worker before a caller or a requirement needs it.
- Do not put a `.package(path:)` in a manifest to bridge an untagged shared package; tag it first.
- Do not start the stack with a value missing from `.env` or a key generated into a tracked directory.
