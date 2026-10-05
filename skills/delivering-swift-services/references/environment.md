# Environment

How the system runs as a whole on one machine or one host: images, Compose, ports, secrets, certificates, the address the gateway is reached at, log aggregation, and the order a stack comes up in. Everything about the environment lives here; the building, gateway, and workflow skills describe the code and say only that a value "comes from the environment".

This file is the worked default: a Compose suite, a `step`-issued CA, Loki. Every section satisfies a principle the skill's rules state, and the rules name the alternative for a platform that provides the same thing differently (a mesh for identity, a collector for logs, a managed cluster for Postgres); satisfy the principle, then keep whichever mechanism the platform gives you.

## Contents

- Container build
- The suite Compose file
- Postgres and migrations
- Ports
- Secrets
- Transport security: the certificate volume
- The gateway's address
- Log aggregation
- Verifying what a service receives
- Platforms without Compose secrets

## Container build

The images the environment runs come from the delivery pipeline, built per commit with the project's recorded image tool (see *The release image* in [delivery.md](delivery.md)); nothing here builds what production pulls. For a local build on a workstation, and as the fallback when the pipeline cannot run, every service carries the same `Makefile` wrapping the project's local build. This example uses `swift-container-plugin` with the static Linux SDK, with no Docker daemon involved; a project on Docker or Apple's `container` wraps that command instead:

```make
TAG ?= $(shell git rev-parse --short=7 HEAD)        # the same short SHA CI tags
SWIFT_SDK ?= aarch64-swift-linux-musl     # or x86_64-swift-linux-musl for the target host

build:
	swift package --disable-automatic-resolution --swift-sdk $(SWIFT_SDK) \
		--configuration release \
		--allow-network-connections all build-container-image \
		--product catalog \
		--repository ghcr.io/<organization>/<organization>-catalog \
		--tag $(TAG)

.PHONY: build
```

Replace only service, product, and repository names. One image per service, whether or not it has a Temporal worker: the worker runs the same image with `worker run` as its command. A container-plugin image's creation date is the epoch, so image age says nothing about freshness; probe a feature (`--help` listing a subcommand) instead.

## The suite Compose file

One `compose.yml` at the workspace root runs the whole system from published images and never builds them: `${REGISTRY:-ghcr.io/<organization>}/<image>:${IMAGE_TAG:?set a published branch or SHA tag}` with `pull_policy: ${PULL_POLICY:-always}`. Beside it, a `.env.example` names every variable with the required ones left empty, copied to a git-ignored `.env`; a required secret is declared as `${VAR:?message}` so Compose refuses to start with an actionable error rather than a guessable default. Each service package also carries a standalone `compose.yaml` for running that service alone.

Shared configuration is declared once as anchors and merged into every service that needs it:

```yaml
x-jwt-verification: &jwt-verification
  JWT_PUBLIC_KEY_PATH: /run/secrets/jwt-public

x-tls: &tls
  TLS_CERTIFICATE_PATH: /run/tls/cert.pem
  TLS_PRIVATE_KEY_PATH: /run/tls/key.pem
  TLS_TRUST_ROOTS_PATH: /run/tls/ca.pem

x-temporal: &temporal
  TEMPORAL_HOST: temporal
  TEMPORAL_PORT: "7233"
  TEMPORAL_TLS_CERTIFICATE_PATH: /run/temporal-tls/cert.pem
  TEMPORAL_TLS_PRIVATE_KEY_PATH: /run/temporal-tls/key.pem
  TEMPORAL_TLS_TRUST_ROOTS_PATH: /run/temporal-tls/ca.pem

x-observability: &observability
  LOKI_URL: ${LOKI_URL:-http://loki:3100}
```

An explicit key in a mapping wins over `<<:`, which is how a service overrides what an anchor merges in. Verify an anchor is actually referenced: an unreferenced one is silently ignored, so a `${VAR:?message}` guard inside it never fires and the stack starts without a value the service requires.

Consumers reach producers by service name: `GRPC_<SERVICE>_HOST=<service>`, `GRPC_<SERVICE>_PORT=50051` — the container port, whatever the host publishes. Startup is gated with `depends_on` conditions, which help ordering and do not replace runtime recovery: the application must tolerate a dependency restarting.

## Postgres and migrations

Where Postgres runs is the project's choice (see *Where a service's data lives* in the building-swift-services skill's persistence reference); this worked example runs one instance per service — `<service>-postgres`, `postgres:18`, its own volume mounted at `/var/lib/postgresql` (PostgreSQL 18 changed the image's volume layout; do not set a custom `PGDATA`), a health check, and no `ports:`. The instance is provisioned with its database and owner through the image's own variables, so there is no init job and nothing ever creates a database. A project that runs one shared instance with a database per service instead creates each `<project>_<service>` database and its owner once while provisioning, the owner with `CREATEROLE` so its role migrations can run, and that per-service owner is the pair the service migrates as; the ownership rule survives either shape.

Per service:

- `<service>`: `command: ["serve", "--migrate-database"]`, gated on its instance's health check. Migrations run in-process as the owner before the server binds; serving connects as the service role its migrations create. This example uses no migrate one-shot.
- `<service>-worker`: the service's image with `command: ["worker", "run"]`, at the same tag, when the service uses Temporal — with the internal-service clients and Temporal configuration its Activities need, and the Postgres connection to its own service's database as the worker role: `POSTGRES_WORKER_USER` / `POSTGRES_WORKER_PASSWORD` and never the owner pair. No `*jwt-verification`, because it verifies no token.

```yaml
<service>-postgres:
  image: postgres:18
  environment:
    POSTGRES_DB: <project>_<service>
    POSTGRES_USER: ${<SERVICE>_OWNER:-<organization>}
    POSTGRES_PASSWORD: ${<SERVICE>_OWNER_PASSWORD:?set the instance owner password}
  volumes:
    - <service>-postgres-data:/var/lib/postgresql

<service>:
  command: ["serve", "--migrate-database"]
  environment:
    <<: [*jwt-verification, *tls, *observability]
    POSTGRES_HOST: <service>-postgres
    POSTGRES_PORT: "5432"
    POSTGRES_DB: <project>_<service>
    POSTGRES_USER: ${<SERVICE>_OWNER:-<organization>}          # the database's owner (here the instance's pair), verbatim — migrations only
    POSTGRES_PASSWORD: ${<SERVICE>_OWNER_PASSWORD:?set the instance owner password}
    POSTGRES_SERVICE_USER: ${<SERVICE>_SERVICE_ROLE:-<service>_service}
    POSTGRES_SERVICE_PASSWORD: ${<SERVICE>_SERVICE_PASSWORD:?set the service role password}
    POSTGRES_INTERNAL_USER: ${<SERVICE>_INTERNAL_ROLE:-<service>_internal}         # only a tenant service
    POSTGRES_INTERNAL_PASSWORD: ${<SERVICE>_INTERNAL_PASSWORD:?set the internal role password}
    POSTGRES_WORKER_USER: ${<SERVICE>_WORKER_ROLE:-<service>_worker}               # only with a worker: CreateWorkerRole reads it
    POSTGRES_WORKER_PASSWORD: ${<SERVICE>_WORKER_PASSWORD:?set the worker role password}
    # With Temporal, serve starts workflows too: merge *temporal, set TEMPORAL_CLIENT_NAMESPACE
    # and TEMPORAL_TASK_QUEUE: <service>, and mount its Temporal leaf at /run/temporal-tls.

<service>-worker:
  image: ${REGISTRY:-ghcr.io/<organization>}/<organization>-<service>:${IMAGE_TAG:?set a published branch or SHA tag}
  command: ["worker", "run"]
  environment:
    <<: [*tls, *temporal, *observability]                       # *tls only when its Activities call another service
    POSTGRES_HOST: <service>-postgres
    POSTGRES_DB: <project>_<service>
    POSTGRES_WORKER_USER: ${<SERVICE>_WORKER_ROLE:-<service>_worker}
    POSTGRES_WORKER_PASSWORD: ${<SERVICE>_WORKER_PASSWORD:?set the worker role password}
    TEMPORAL_WORKER_NAMESPACE: ${TEMPORAL_NAMESPACE:?set the Temporal namespace}
    TEMPORAL_WORKER_TASKQUEUE: <service>
    TEMPORAL_WORKER_HEARTBEATINTERVALMS: "60000"
    GRPC_<UPSTREAM>_HOST: <upstream>                           # only when its Activities call another service
    GRPC_<UPSTREAM>_PORT: "50051"
  volumes:
    - <service>-worker-tls:/run/tls:ro                          # its own leaf, written by its renewer; only with *tls
    - <service>-worker-temporal-tls:/run/temporal-tls:ro
```

The service's Postgres block repeats the instance's `POSTGRES_*` values because the app reads them as the owner connection; the `SERVICE_*` pair names the tenant-scoped role serving uses and the `INTERNAL_*` pair the one that sees every row. The serving container also carries the worker role's pair when there is a worker, because the `CreateWorkerRole` migration it runs at boot reads that password. The worker gets its own role's pair and no owner pair at all. The owner pair sits in the serving container's environment — the accepted price of in-process migration; the serving *process* never connects with it.

The migration library refuses a migration list whose order differs from what a database has already applied — it throws, it does not revert. A change that inserts a migration before applied ones therefore means `docker compose down -v` and a fresh start, not an in-place `up`. Appending a migration, a role added later included, applies in place.

## Ports

Publish nothing that nothing outside the stack calls. Postgres, the cache, Temporal, the log store, and the gateway get no `ports:`; the gateway is reached through its sidecar or the platform ingress (below), and internal services by name. Where a gRPC port is published for development convenience, make it a variable with a default — `${USERS_HOST_PORT:-50052}:50051` — so a collision is settled in `.env` rather than by editing the file, and remember that two services defaulting to the same host port fail at `up`, not at `config`. Reach an internal service with `docker compose exec` rather than opening a port.

## Secrets

Key material (signing keys, TLS keys and certificates, enrollment credentials) is mounted as files and configured by path — never as an environment variable, which is readable from `/proc/<pid>/environ`, reported by the runtime's inspect command, and inherited by every child process:

```yaml
secrets:
  jwt-public:
    file: ./secrets/jwt-public.pem
  jwt-private:
    file: ./secrets/jwt-private.pem

services:
  authentication:
    environment:
      <<: [*jwt-verification, *tls, *observability]
      JWT_PRIVATE_KEY_PATH: /run/secrets/jwt-private
    secrets:
      - jwt-public
      - jwt-private
```

Only the authenticating service mounts the private key. Every service that verifies tokens merges `*jwt-verification` and mounts `jwt-public`; a worker mounts neither. Compose refuses to start a service whose secret's source file is missing, so a stack without keys fails at `up` rather than at the first request — the same guarantee a `${VAR:?message}` guard gives a variable. `docker compose config` validates a file whose secret source is missing; only `up` refuses.

Signing keys, TLS private keys, and enrollment credentials are secret files. Database role passwords are the one secret that stays a variable: the Postgres driver takes them as values, so they come from `${VAR:?message}` guards in the environment and the application reads them with `isSecret: true`, which keeps them out of its logs. Provision each workload’s initial certificate before startup, then keep a renewer running beside it.

JWT key rotation and TLS renewal have separate lifecycles. TLS leaves reload for new handshakes; CA trust changes require transport reconstruction.

## Transport security: the certificate volume

All internal gRPC connections use mTLS: gateway upstreams, service calls, worker calls, and Temporal frontend connections. Explicit roots define admitted peers. Certificates need the TLS purposes used by the process and DNS SANs for the names clients actually dial, including a Dokploy service's assigned internal DNS name. No application URI identity is needed.

Use Smallstep `step-ca` for issuance and `step` for enrollment, renewal, and rekeying. The online CA signs leaves with an intermediate; keep the root signing key offline and protect the intermediate key and unlock password. Do not distribute CA private keys to application containers. Pin reviewed image versions or digests and retain CA state across redeployments. See [Smallstep production guidance](https://smallstep.com/docs/step-ca/certificate-authority-server-production/).

### Mounts and scopes

Give each workload instance its own directory containing `cert.pem` (leaf plus intermediates), `key.pem`, and `ca.pem` (trusted peers). The application mounts its directory read-only at `/run/tls`; its renewer mounts that same directory read-write. Do not mount a volume containing every workload's keys into every application. Directory mounts allow atomic replacement of files; individual file bind mounts can retain the old inode.

Temporal clients use separate files under `/run/temporal-tls`, independent `TEMPORAL_TLS_*` overrides, and a separate reloader even when the CA operator is the same. Trust bundles can differ by destination. Issue client/server EKUs appropriate to each use and protect key files with ownership and restrictive permissions that the actual container UID can read.

The executable's application-default provider supplies the conventional paths. Repeat path environment variables only when overriding them; deployment supplies mounts, upstream addresses, and secrets. See the building skill's [configuration guide](../../building-swift-services/references/configuration.md).

### Initial issuance

Initialize the CA once, back up its state, and establish trust in its root through a verified channel. Enroll each workload using a narrowly scoped provisioner and short-lived enrollment credential. Issue only its required SANs and TLS purposes. Remove disposable enrollment secrets and jobs after successful publication; the application's own container never needs CA administration credentials.

The application starts after its initial files are available. `TimedCertificateReloader.makeReloaderValidatingSources` rejects unusable certificate/key material at startup. The reloader is from `NIOCertificateReloading` in swift-nio-extras and runs in `ServiceGroup` with the gRPC or Temporal clients/server. It reads files; it does not request certificates from the CA.

### Renewal and key rotation

Run a `smallstep/step-cli` companion or a host service with a restart policy for each credential directory. A foreground renewal loop can use:

```sh
step ca renew /run/tls/cert.pem /run/tls/key.pem \
  --ca-url https://step-ca.internal:9000 \
  --root /run/tls/ca.pem \
  --daemon \
  --expires-in 8h
```

Here the CA endpoint is assumed to chain to that bundle; otherwise mount its root separately. Renewal normally authenticates with the current certificate/key and keeps the private key. A 24-hour leaf, renewal with eight hours remaining, and a 60-second application reload interval are example settings to test against the outage budget, not universal requirements. See [`step ca renew`](https://smallstep.com/docs/step-cli/reference/ca/renew/).

Use [`step ca rekey`](https://smallstep.com/docs/step-cli/reference/ca/rekey/) for a new private key. Stage and validate the new pair before publishing it. Two separate file renames are not a pair-atomic operation; coordinate publication and verify that a reader never activates a mismatched pair. Test the pinned renewer's behavior on the actual mounted filesystem. Failed application reloads retain the last usable pair and retry.

New TLS handshakes use the renewed pair; existing connections do not. Bound server connection age and drain grace so clients reconnect within the certificate lifecycle, accounting for long streams. Monitor renewal errors, reload failures, and remaining lifetime. Test CA downtime and controlled reenrollment after expiry. Revoking renewal at the CA does not by itself terminate existing TLS sessions or make every client check a revocation list.

Rotate trust roots with an overlap of old and new trust, then rebuild transports or roll the applications before removing old trust. The leaf reloader does not reload CA bundles.

### Temporal and verification

Configure the Temporal server's frontend and internode TLS and every enabled supporting client explicitly. Its native certificate refresh is separate from Swift's reloader; verify the pinned server's reload behavior or roll it within the renewal window. Do not assume a Temporal namespace is a TLS authorization boundary. Keep the Temporal API private and define admission for each environment.

Use real handshakes to prove rejection of missing/untrusted/expired client certificates and wrong server hostnames. Renew a leaf and verify the changed serial on a fresh connection without restarting Swift. Exercise a mismatched update, renewer and application restarts, CA downtime, connection draining, and overlapping CA rotation.

## The gateway's address

The gateway publishes no host port. Something else owns its public address and proxies to it; the gateway is reached by that thing and by nothing else.

The default is a tailnet sidecar (Tailscale): it owns the node identity, the certificate, and optionally public exposure (Funnel), and the gateway runs inside the sidecar's network namespace, reached at localhost:

```yaml
api-tailscale:
  image: tailscale/tailscale:latest
  hostname: <project>-api                       # the node, and so the DNS name, on the tailnet
  environment:
    TS_AUTHKEY: ${TS_AUTHKEY:-}                 # first registration only; state re-registers itself
    TS_SERVE_CONFIG: /config/serve-api.json
    TS_STATE_DIR: /var/lib/tailscale
  volumes:
    - ./state/api:/var/lib/tailscale            # the node's identity and certificate (root-owned)
    - ./config:/config
    - /dev/net/tun:/dev/net/tun
  cap_add:
    - net_admin
    - sys_module
  restart: unless-stopped

api:
  network_mode: service:api-tailscale           # same namespace: the sidecar proxies to localhost
  depends_on:
    api-tailscale:
      condition: service_started
  # no ports
```

`config/serve-api.json` terminates HTTPS on 443 for the node's certificate domain and proxies to `http://127.0.0.1:8080`; `AllowFunnel` for that domain makes it public. The gateway still resolves upstreams by service name from inside the shared namespace. Nothing listens on a host port, so nothing collides with whatever else the machine runs and nothing is reachable by IP.

Two facts that matter at a cutover. The public address *is* the node's identity in `state/api`: moving a service behind that hostname means moving the state directory into the new stack — it is root-owned, so copy it through a container (`docker run --rm -v old:/src:ro -v new:/dst alpine cp -a /src /dst/api`) — not registering a new node. And the serve config routes by path prefix, longest match first, so a strangler cutover — the new gateway for most paths, the old one for the few it does not serve yet — is a handler per prefix in one config rather than two hostnames.

On a platform with its own ingress, the ingress plays the sidecar's part: it terminates public TLS and routes to the gateway's container port, and still nothing else is exposed. Where neither exists, publish the gateway's HTTP port as a variable, and still nothing else.

## Log aggregation

Every process ships its own logs. There is no log-scraping agent: the in-process shipper batches and pushes to the aggregator directly (see the building-swift-services skill's composition reference), so a service that runs anywhere with a route to the aggregator is aggregated, container or not. The default is Grafana Loki for storage and Grafana for dashboards, and one anchor (`*observability` above) points every process at it.

```yaml
# Log store. Single-binary filesystem mode on the image's default config — schema v13, which keeps
# the per-line structured metadata each service attaches. No host port; only Grafana reads it.
loki:
  image: grafana/loki:3.0.0
  command: ["-config.file=/etc/loki/local-config.yaml"]
  volumes:
    - loki-data:/loki
  restart: unless-stopped

# Dashboards. Behind its own sidecar, exactly like the gateway — a private node, no host
# port — and pointed at Loki out of the box by a provisioned datasource.
grafana:
  image: grafana/grafana:latest
  network_mode: service:grafana-tailscale
  environment:
    GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER:-admin}
    GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:?set the Grafana admin password}
  volumes:
    - grafana-data:/var/lib/grafana
    - ./config/grafana/provisioning:/etc/grafana/provisioning   # datasources/loki.yaml
  depends_on:
    loki:
      condition: service_started
    grafana-tailscale:
      condition: service_started
  restart: unless-stopped
```

The `grafana-tailscale` sidecar is the gateway's sidecar with a different `hostname` and `serve-grafana.json` (proxying `http://127.0.0.1:3000`). `config/grafana/provisioning/datasources/loki.yaml` declares the Loki datasource (`type: loki`, `url: http://loki:3100`, `isDefault: true`) so Grafana comes up ready to query with no manual step. Unset `LOKI_URL` to log to stdout alone.

Reuse across a cutover works like the gateway's node: Grafana's identity and its stored dashboards live in `state/grafana` and `grafana-data`; moving the dashboards behind the same hostname means moving that state, not registering a new node.

## Verifying what a service receives

`docker compose config <service>` renders exactly the environment, secrets, and ports a service will get, anchors merged and variables substituted. Use it before `up` whenever an anchor, a `${VAR:?}` guard, or an override is touched. A live check after `up`: which role each service connected as (`pg_stat_activity`), which node the sidecar registered (`tailscale status --self`), and a request through the public hostname from a machine that can reach it.

## Platforms without Compose secrets

The equivalent of a secret is a file mount plus the path variable. Certificate directories must be shared between each application and its renewer, with application mounts read-only. Verify that both reach the same files on the scheduled node. Most such platforms deploy a container whose mount is missing rather than refusing, so the failure appears in the logs as an unreadable key instead of a failed deploy — check them after the first rollout rather than reading a green deploy as proof the mount landed.
