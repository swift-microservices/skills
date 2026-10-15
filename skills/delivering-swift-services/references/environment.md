# Environment

How the system runs as a whole on one host or one platform environment: the suite Compose file, where Postgres runs, ports, secrets and signing keys, the certificate volume, public ingress, log aggregation, and how to verify what a service receives. The building, gateway, and workflow skills describe the code and say only that a value "comes from the environment". Images come from [delivery.md](delivery.md); certificate issuance and renewal live in [certificates.md](certificates.md).

This file is the worked default: a Compose suite, a `step`-issued CA, Loki. Each section satisfies a principle the skill's rules state; a platform that provides the same thing differently (a mesh for identity, a collector for logs, a managed cluster for Postgres) satisfies the principle and keeps its own mechanism.

## Contents

- [The suite Compose file](#the-suite-compose-file)
- [Where Postgres runs](#where-postgres-runs)
- [Ports](#ports)
- [Secrets](#secrets)
- [Transport security: the certificate volume](#transport-security-the-certificate-volume)
- [Public ingress](#public-ingress)
- [Log aggregation](#log-aggregation)
- [Verifying what a service receives](#verifying-what-a-service-receives)
- [Platforms without Compose secrets](#platforms-without-compose-secrets)

## The suite Compose file

One `compose.yaml` at the workspace root runs the whole system from published images and never builds them. Start from [the suite skeleton](../assets/compose.yaml), [the variables](../assets/env.example), and [the certificate machinery](../assets/ca-compose.yaml), merged through `COMPOSE_FILE` in `.env`:

- every image is `${REGISTRY}/<organization>-<service>:${<SERVICE>_IMAGE_TAG:?…}`, a published short SHA (pinned) or branch tag (followed); every third-party image is pinned to a reviewed version or digest, never `latest`;
- `.env.example` names every variable with the required ones empty, copied to a git-ignored `.env`; each required value is `${VAR:?message}`, so Compose refuses to start with an actionable error rather than a guessable default;
- startup is gated by health: a service `depends_on` its Postgres with `condition: service_healthy` and on its renewer the same way; a one-shot is `service_completed_successfully`. Gating helps ordering and does not replace runtime recovery: the application must tolerate a dependency restarting;
- consumers reach producers by service name on the internal network: `GRPC_<SERVICE>_HOST=<service>`, `GRPC_<SERVICE>_PORT=50051`, the container port.

Shared configuration is declared once as anchors (`x-tls`, `x-jwt-verification`, `x-temporal`, `x-observability`) and merged with `<<:`. An explicit key in a mapping wins over the merge. Verify each anchor is referenced: an unreferenced one is silently ignored, so a `${VAR:?}` guard inside it never fires. Each service package may also carry a standalone `compose.yaml` for running that service alone, from the same images.

Credentials per process, which the skeleton spells out:

| Process | Database pair | Key files |
| --- | --- | --- |
| `<service>` (`serve --migrate-database`) | owner (migrations only), `SERVICE_*`, `INTERNAL_*` for a tenant service, `WORKER_*` when a worker exists (its role migration reads that password) | `/run/tls`, `jwt-public`; `/run/temporal-tls` when it starts workflows |
| `<service>-worker` (`worker run`) | `WORKER_*` only, never the owner | its own `/run/tls` when its Activities call another service or Temporal shares the process's pair, its own `/run/temporal-tls` otherwise; no JWT key |
| the authenticating service | as `<service>` | adds `jwt-private` |

Why the owner pair sits in the serving container, and what a migration-order change requires, is in *Migrations* in [delivery.md](delivery.md#migrations).

## Where Postgres runs

Placement is the project's choice per environment (see *Where a service's data lives* in the building skill's [migrations reference](../../building-swift-services/references/migrations-and-rls.md#where-a-services-data-lives)); the ownership rule survives every shape. The worked example runs one instance per service: `<service>-postgres` on a pinned `postgres:18.x` image, its own volume mounted at `/var/lib/postgresql` (PostgreSQL 18 changed the image's volume layout; do not set a custom `PGDATA`), a `pg_isready -h 127.0.0.1` health check, and no `ports:`. The image's own variables provision the database and owner, so there is no init job. A shared instance instead creates each `<project>_<service>` database and a distinct owner once while provisioning, the owner with `CREATEROLE` so its role migrations run; role names are cluster-wide, so each service's roles are named distinctly.

## Ports

Publish nothing that nothing outside the stack calls. Postgres, the cache, Temporal, the log store, the CA, and the gateway get no `ports:`; internal services are reached by name, and a client-facing listener (the gateway, or a monolith apps call directly) only through the edge proxy. Reach an internal service with `docker compose exec` rather than opening a port. Where a gRPC port is published for development convenience, make it a variable with a default (`${USERS_HOST_PORT:-50052}:50051`) so a collision is settled in `.env`; two services defaulting to the same host port fail at `up`, not at `config`.

## Secrets

Key material (signing keys, TLS keys and certificates, enrollment tokens, the CA password) is mounted as files and configured by path, never an environment variable, which is readable from `/proc/<pid>/environ`, reported by the runtime's inspect command, and inherited by every child process.

Generate the token signing pair with [generate-jwt-keys.sh](../assets/generate-jwt-keys.sh) into a git-ignored directory: Ed25519 PEM files written under `umask 077`, refusing to overwrite an existing pair because rotating invalidates every access token in flight. The private key must be readable by the image's numeric user where it is mounted (Compose file secrets keep host ownership). Only the authenticating service mounts `jwt-private` and sets `JWT_PRIVATE_KEY_PATH`; every service that verifies tokens merges `*jwt-verification` and mounts `jwt-public`; a worker mounts neither. Compose refuses to start a service whose secret file is missing, so a stack without keys fails at `up`; `docker compose config` alone does not check the file.

Database role passwords are the one secret that stays a variable: the Postgres driver takes them as values, so they come from `${VAR:?}` guards and the application reads them with `isSecret: true`, which keeps them out of its logs. JWT rotation and TLS renewal have separate lifecycles.

## Transport security: the certificate volume

All internal gRPC connections use mTLS (gateway upstreams, service calls, worker calls, and Temporal), with explicit trust roots and verified server DNS names, and no plaintext mode, locally included. A client-facing listener is TLS with the same leaf and requires no client certificate ([Public ingress](#public-ingress)); it is the only listener without one. Each process mounts its own credential directory read-only at `/run/tls` (`cert.pem`, `key.pem`, `ca.pem`), and, where the project gives Temporal its own pair, Temporal credentials separately at `/run/temporal-tls`; a renewer per directory is the only writer. Issuance, provisioners, enrollment, renewal, rekey, trust rotation, numeric ownership, the Temporal trust decision, the local development CA, and verification are in [certificates.md](certificates.md).

## Public ingress

Clients reach the system only through the edge, and the edge is the project's choice, recorded in `AGENTS.md`. Whatever it is, it meets this contract:

- Public TLS terminates at the edge, and the edge verifies the origin strictly: it connects only over TLS and only to a certificate it trusts for that hostname.
- The hop from the proxy to the process stays on the private network and is TLS: the process presents its leaf from the stack's CA (a DNS SAN covers the name the proxy dials), and the proxy verifies it against the stack's root. No hop is plaintext.
- A client-facing listener — the gateway's HTTP port, or the client-facing gRPC port of a monolith that apps or partners call directly — requires no client certificate; callers are identified by bearer JWT. The proxy routes to client-facing listeners only, never to an internal (mTLS) port.
- The process publishes no host port; only the proxy does.

**The worked example: Cloudflare in front of Dokploy's Traefik.**

- *Cloudflare.* A proxied DNS record per public hostname; SSL/TLS encryption mode **Full (Strict)**, so Cloudflare refuses an origin whose certificate it cannot verify. For a gRPC hostname, enable **gRPC** in the zone's Network settings; Cloudflare then speaks HTTP/2 over TLS to the origin, so the proxy's entry point and the process's listener both negotiate `h2`.
- *The origin certificate.* Traefik presents a certificate Cloudflare trusts for the hostname: a Cloudflare Origin CA certificate (trusted only by Cloudflare, long-lived, kept as a file) or a publicly trusted one. It is the proxy's credential, not a workload's, and it never comes from the stack's CA.
- *Traefik to the process.* The router serves the hostname on the TLS entry point with the origin certificate; the service URL is `https://`, and a `serversTransport` names the stack's root and the server name the leaf carries:

```yaml
# Traefik dynamic configuration (Dokploy: the application's Traefik configuration, or a file in
# Traefik's dynamic directory). Paths are where the Traefik container sees the files.
http:
  routers:
    <project>-api:
      rule: Host(`api.<domain>`)
      entryPoints: [websecure]
      service: <project>-api
      tls: {}
  services:
    <project>-api:
      loadBalancer:
        serversTransport: <project>-stack-ca
        servers:
          - url: https://<project>-api:8080    # a gRPC monolith: its client-facing gRPC port; Traefik negotiates h2
  serversTransports:
    <project>-stack-ca:
      serverName: <project>-api                # a DNS SAN of the process's leaf
      rootCAs: [/etc/traefik/<project>/ca.pem] # the stack's published root, refreshed on rotation
tls:
  certificates:
    - certFile: /etc/traefik/<project>/origin.pem
      keyFile: /etc/traefik/<project>/origin-key.pem
```

Traefik and the process share the private network (Dokploy's network, or the project network Traefik is attached to); Traefik's ports are the only published ones. The stack's root in `rootCAs` is one more consumer of the published trust bundle, so a CA rotation updates it before the old root is withdrawn ([certificates.md](certificates.md)).

**Alternatives.** A cloud load balancer or another reverse proxy meets the contract the same way: strict verification at the edge, TLS to the process verified against the stack's root. The [suite skeleton](../assets/compose.yaml) runs the edge as a `proxy` service (Traefik, the only published port) with the origin pair and the stack's root as Compose secrets; on Dokploy the platform's Traefik takes its place. A tailnet sidecar, commented in the skeleton, is the alternative edge for a private deployment: it owns the node identity and certificate (and public exposure through Funnel), and the gateway runs in its network namespace. It meets the contract only when `config/serve-api.json` proxies to `https://` with the stack's root added to the sidecar's trust store and the gateway's leaf naming `localhost`; `https+insecure://` skips verification and `http://` is plaintext, so neither is allowed. Its public address is the node's identity in `state/api` (root-owned): back it up with the stack, because a new state directory registers a new node under a new address.

## Log aggregation

Every process ships its own logs; there is no scraping agent. The in-process shipper batches and pushes to the aggregator directly (see the building skill's composition reference), so a process that runs anywhere with a route to the aggregator is aggregated. The default is Grafana Loki for storage and Grafana for dashboards, and the `*observability` anchor points every process at it. Unset `LOKI_URL` to log to stdout alone.

```yaml
# Dashboards behind their own tailnet sidecar: a private node, no host port.
grafana:
  image: grafana/grafana:12.2.0
  network_mode: service:grafana-tailscale
  environment:
    GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER:-admin}
    GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:?set the Grafana admin password}
  volumes:
    - grafana-data:/var/lib/grafana
    - ./config/grafana/provisioning:/etc/grafana/provisioning:ro   # datasources/loki.yaml
  depends_on:
    loki:
      condition: service_started
    grafana-tailscale:
      condition: service_started
  restart: unless-stopped
```

Loki runs single-binary on the image's default configuration (schema v13 keeps the per-line structured metadata each service attaches), as in the skeleton. The `grafana-tailscale` sidecar is the skeleton's commented tailnet sidecar with another `hostname` and `serve-grafana.json` proxying `http://127.0.0.1:3000`. `config/grafana/provisioning/datasources/loki.yaml` declares the Loki datasource (`type: loki`, `url: http://loki:3100`, `isDefault: true`), so Grafana starts ready to query.

## Verifying what a service receives

`docker compose config <service>` renders exactly the environment, secrets, volumes, and ports a service will get, anchors merged and variables substituted. Run it before `up` whenever an anchor, a guard, or an override changes. After `up`, check which role each service connected as (`pg_stat_activity`: the service, internal, and worker roles, never the owner), each internal listener's certificate with [certificate-verify-peer.sh](../assets/certificate-verify-peer.sh), that a client-facing listener completes a TLS handshake with no client certificate and answers `401` (or `unauthenticated`) to a request without a token, and a request through the public hostname from a machine that can reach it.

## Platforms without Compose secrets

The equivalent of a secret is a file mount plus the path variable. Each certificate directory is shared between one application and its renewer; verify that both reach the same storage on the scheduled node. Most such platforms deploy a container whose mount is missing rather than refusing, so the failure appears in the logs as an unreadable key instead of a failed deploy: check them after the first rollout rather than reading a green deploy as proof the mount landed. Platform-specific traps (read-only mounts, aliases, persisted files, external volumes, stop grace) are in [delivery.md](delivery.md#platform-configuration-and-its-traps).
