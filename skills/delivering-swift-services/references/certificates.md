# Certificates

How every internal connection gets its mTLS credentials, and every client-facing listener the server leaf the edge proxy verifies: the contract any CA must satisfy, and Smallstep `step-ca` as its worked example — initialization, provisioners, enrollment, renewal, rekey, trust rotation, Temporal TLS, and the local development CA. The CA is a project choice recorded once in `AGENTS.md`; [environment.md](environment.md) owns how the rest of the stack runs, and the building skill's [transport security factories](../../building-swift-services/references/transport-security.md#transport-security-factories) own how a process loads and reloads the files.

## Contents

- [The contract](#the-contract)
- [Assets: execute or copy](#assets-execute-or-copy)
- [Files, owners, and mounts](#files-owners-and-mounts)
- [The CA: step-ca](#the-ca-step-ca)
- [Provisioners: one per workload](#provisioners-one-per-workload)
- [Enrollment](#enrollment)
- [Renewal and publication](#renewal-and-publication)
- [Rekey and trust rotation](#rekey-and-trust-rotation)
- [Application reload](#application-reload)
- [Temporal TLS](#temporal-tls)
- [Local development CA](#local-development-ca)
- [Verification and monitoring](#verification-and-monitoring)

## The contract

Any CA the stack controls satisfies the rules if it:

- is private to the stack, one per environment, so no environment trusts another's leaves by default;
- keeps its root signing key offline and its online signing key and password only in the CA;
- issues each workload a leaf with a fixed subject, the DNS SANs clients and the edge proxy actually dial, both client and server TLS purposes (a workload that only dials out, such as a worker or Temporal client, keeps both too, so one provisioner template serves every leaf), and a bounded lifetime; no application URI identity is needed;
- enrolls a workload only with a credential scoped to that workload, short-lived and single-use, so neither an application nor a renewer can enroll a peer;
- keeps a renewer running per credential directory that publishes `cert.pem`, `key.pem`, and `ca.pem` atomically, while the application only reads them.

Alternatives that satisfy it: a cloud private CA or a service mesh that issues, renews, and publishes the same three files. A mesh that terminates mTLS itself replaces the files only where the project records that the application's own listener trusts the mesh.

## Assets: execute or copy

| Asset | How it is used |
| --- | --- |
| [ca-compose.yaml](../assets/ca-compose.yaml) | Copy beside `compose.yaml` and edit: one enroll/renew pair, one permission entry, and one dependency per credential directory |
| [certificate-enroll.sh](../assets/certificate-enroll.sh) | Execute unchanged in the enrollment one-shot; configured by environment variables |
| [certificate-renew.sh](../assets/certificate-renew.sh) | Execute unchanged in every renewer; configured by environment variables |
| [certificate-publish.sh](../assets/certificate-publish.sh) | Execute unchanged; the renewer calls it with the new certificate and the directory |
| [certificate-verify-peer.sh](../assets/certificate-verify-peer.sh) | Execute unchanged from a container on the private network: `HOST PORT CA_FILE CLIENT_CERT CLIENT_KEY` |
| [certificate-local-ca.sh](../assets/certificate-local-ca.sh) | Execute unchanged, local development only |

"Unchanged" means copied into the stack's `scripts/` directory and mounted read-only; durations, IDs, and names arrive as arguments or variables, and a missing one stops the script with its name.

## Files, owners, and mounts

Each workload instance (every serving process and every worker) has its own directory with `cert.pem` (leaf plus intermediates), `key.pem`, and `ca.pem` (the trust for peers). The application mounts it read-only at `/run/tls`; its renewer mounts the same directory read-write. Never mount a volume holding every workload's keys into every application. Mount directories, not single files: a file bind mount keeps the old inode after an atomic rename.

Use numeric IDs so ownership enforces the split even where a platform cannot mount read-only:

- Images run as the [Containerfile](../assets/Containerfile)'s `app` user; `APP_GID` is its numeric group, read from the built image with `docker run --rm --entrypoint id <image>`.
- Renewers and the enrollment one-shot run as `RENEWER_UID:APP_GID`, a different user in the same group.
- Each directory is `RENEWER_UID:APP_GID` with mode `2750`; `key.pem` is `0640`, `cert.pem` and `ca.pem` are `0644`. The application reads, and cannot create, rename, or replace a file.

Fresh volumes are root-owned, so a `permission-init` one-shot (root, no network, `restart: "no"`) hands each directory to those IDs before enrollment. The application's default configuration supplies the conventional paths; set `TLS_*` and `TEMPORAL_TLS_*` variables only to override them (see the building skill's [configuration guide](../../building-swift-services/references/configuration.md)).

## The CA: step-ca

Initialize on an offline machine. The root key never leaves it; the CA receives an intermediate whose key is encrypted with a password the CA reads from a separate secret file.

```sh
step certificate create "<Project> <environment> Root CA" root_ca.crt root_ca_key --profile root-ca
STEPPATH=/run/pki step ca init --deployment-type standalone \
  --name "<Project> <environment>" --dns ca --dns <ca-alias> --address :9000 \
  --root root_ca.crt --key root_ca_key \
  --provisioner bootstrap --password-file intermediate-password \
  --provisioner-password-file bootstrap-password
step ca provisioner remove bootstrap --ca-config /run/pki/config/ca.json
```

`STEPPATH` set to the path the container mounts keeps the paths in `ca.json` valid inside it; otherwise rewrite `root`, `crt`, `key`, and `db.dataSource`. Prime the PKI volume with `config/ca.json`, `certs/root_ca.crt`, `certs/intermediate_ca.crt`, and the encrypted `secrets/intermediate_ca_key` — not the root key, not the password. Establish trust in `root_ca.crt` through a verified channel and back up the root key and the provisioner keys offline.

The relevant parts of `ca.json` (durations are the project's choice; a 24-hour leaf renewed with eight hours left is a common start, and short leaves such as ten minutes exercise renewal continuously in staging):

```json
{
  "root": "/run/pki/certs/root_ca.crt",
  "crt": "/run/pki/certs/intermediate_ca.crt",
  "key": "/run/pki/secrets/intermediate_ca_key",
  "address": ":9000",
  "dnsNames": ["ca", "<ca-alias>"],
  "db": { "type": "badgerv2", "dataSource": "/run/ca-db" },
  "authority": {
    "claims": {
      "minTLSCertDuration": "<minimum>",
      "defaultTLSCertDuration": "<default>",
      "maxTLSCertDuration": "<maximum>"
    },
    "provisioners": []
  }
}
```

Run it as [ca-compose.yaml](../assets/ca-compose.yaml) does: `step-ca /run/pki/config/ca.json --password-file /run/secrets/ca-password`, the PKI volume read-only, the database on its own persistent volume, a `step ca health --ca-url https://ca:9000 --root …` health check, a pinned reviewed image, no host port, and nothing exposing it through the gateway. Disable auto-deploy on the platform resource that holds the CA: a redeploy must never restart it unattended or initialize a new CA. Back up the database volume with the PKI.

## Provisioners: one per workload

Give every workload its own JWK provisioner whose template fixes the subject and SANs, so a token can only ever produce that workload's leaf. Create the key pair offline and add only the public key, so `ca.json` holds nothing that can mint a token:

```sh
step crypto jwk create <service>.pub.json <service>.key.json
step ca provisioner add <service> --type JWK --public-key <service>.pub.json \
  --x509-template <service>.tpl --ca-config /run/pki/config/ca.json
```

```json
{
  "subject": { "commonName": "<service>" },
  "sans": [
    { "type": "dns", "value": "<service>" },
    { "type": "dns", "value": "<service-alias>" }
  ],
  "keyUsage": ["digitalSignature"],
  "extKeyUsage": ["serverAuth", "clientAuth"]
}
```

The SANs are every name a client dials: the Compose service name, and on a platform the stable network alias (see *Platform configuration and its traps* in [delivery.md](delivery.md#platform-configuration-and-its-traps)). Per-provisioner `claims` may narrow the authority's durations. Adding a workload means a new provisioner and a CA restart; the PKI volume is read-only, so publish the edited `ca.json` from the offline copy.

## Enrollment

Mint a token offline with the workload's provisioner key and deliver it as a file:

```sh
step ca token <service> --provisioner <service> --key <service>.key.json \
  --offline --ca-config pki/config/ca.json --output-file <service>.token
```

A `step ca token` token is valid for five minutes and the CA accepts it once; `--not-after` on this command sets the *certificate's* end, not the token's. Run the enrollment one-shot (`certificate-enroll.sh`) with the token mounted as a secret: it requests the leaf, copies the root as `ca.pem`, verifies the chain, sets the modes, and exits 0 without contacting the CA when a valid leaf is already there. Then delete the token file and, on a platform, the one-shot definition. An expired token means minting another, never widening its lifetime.

## Renewal and publication

`certificate-renew.sh` runs forever beside each application, as a renewer container with a restart policy:

1. `step certificate needs-renewal cert.pem --expires-in $RENEW_BEFORE` decides (exit 0 due, 1 not due, anything else an error it logs).
2. `step ca renew cert.pem key.pem --out <private>/next-cert.pem --force` authenticates with the current leaf and keeps the private key.
3. `certificate-publish.sh` verifies the new certificate against `ca.pem` and checks it matches `key.pem`.
4. It publishes with `mktemp` in the target directory and `mv`: a rename is atomic only within one filesystem, so a reader sees the old file or the new one.

The private directory is a `0700` tmpfs owned by the renewer's UID (`tmpfs: /private:uid=…,gid=…,mode=0700`), so an unpublished certificate never touches the shared volume. Failures retry every interval while the application keeps its last valid leaf. A leaf that expired cannot renew with itself; re-enroll it with a fresh token. The renewer's health check verifies the published leaf, so an application can wait for `service_healthy` at first start.

## Rekey and trust rotation

Use `step ca rekey` for a new private key. Stage and validate the new pair before publishing it. Two file renames are not one atomic operation: coordinate publication and verify that a reader never activates a mismatched pair. A failed application reload keeps the last usable pair and retries; confirm the pinned reloader treats a mismatch as such a failure. Test the pinned renewer on the actual mounted filesystem.

Rotate trust with an overlap: publish a `ca.pem` holding the old and new roots everywhere, the edge proxy's copy included, rebuild transports or roll the applications, switch issuance, and only then remove the old root. The leaf reloader does not reload trust bundles.

## Application reload

The process starts only after its files exist. `TimedCertificateReloader.makeReloaderValidatingSources` (from `NIOCertificateReloading` in swift-nio-extras) rejects unusable material at startup and runs in the `ServiceGroup` beside the gRPC or Temporal transport; it reads files and never requests certificates. New handshakes use the renewed pair; existing connections keep the old one, so bound server connection age and drain grace within the renewal window, accounting for long streams. Revoking at the CA neither ends existing sessions nor makes clients check a revocation list.

## Temporal TLS

Whether Temporal connections get their own pair is a recorded project choice (the worker skill's [Temporal transport security](../../orchestrating-temporal-workflows/references/worker.md#temporal-transport-security)). With their own pair, which the assets show, they use separate credentials under `/run/temporal-tls`, their own `TEMPORAL_TLS_*` overrides, their own reloader, and their own renewer, even when the same CA issues them; a shared server below needs this. With the process's pair, the leaf's SANs and the Temporal server's client-CA trust cover both uses, and `/run/temporal-tls` and its renewer are dropped. Configure the Temporal server's frontend and internode TLS explicitly; its certificate refresh is separate from Swift's reloader, so verify the pinned server's reload behavior, or put its server and UI certificates under a renewer, or calendar their expiry.

How Temporal's certificates are issued, and whether environments share a Temporal server, is the project's choice, recorded in `AGENTS.md`. Common arrangements:

- **A server per environment**, trusting that environment's CA.
- **One server for several environments**, with a CA of its own that issues every environment's Temporal pairs, or trusting each environment's CA as a separate client CA.

The client side is the same in every arrangement: the SDK connects over mTLS with a `TimedCertificateReloader`, as its [Connecting to Temporal](https://swiftpackageindex.com/apple/swift-temporal-sdk/main/documentation/temporal/connecting-to-temporal) article shows. mTLS admits a client to the server, not to a namespace; where one server holds several environments' namespaces, separating them is Temporal's own authorization, which the project configures if it needs it.

## Local development CA

A local stack keeps mTLS; there is no plaintext mode. `certificate-local-ca.sh` creates a throwaway root and issues every directory's leaf directly, with the same files and modes, so the application code path is identical. Its root key lives in a local volume and is never trusted elsewhere. Use it instead of `ca-compose.yaml` (`COMPOSE_FILE=compose.yaml:local-ca-compose.yaml`):

```yaml
volumes:
  local-ca: {}

services:
  local-ca:
    image: smallstep/step-cli:0.31.0
    user: "0:0"
    network_mode: none
    restart: "no"
    environment:
      FILE_OWNER: "${RENEWER_UID:?set the renewers' numeric UID}:${APP_GID:?set the images' numeric GID}"
    entrypoint: ["/bin/sh", "/scripts/certificate-local-ca.sh"]
    command: ["/local-ca", "${LOCAL_LEAF_LIFETIME:?set the local leaf lifetime}",
              "<service>,localhost", "/volumes/<service>-tls"]
    volumes:
      - local-ca:/local-ca
      - <service>-tls:/volumes/<service>-tls
      - ./scripts:/scripts:ro

  <service>:
    depends_on:
      local-ca:
        condition: service_completed_successfully
```

Add `localhost` to the names only for a process run on the host rather than in Compose. Rerunning reissues expired leaves and leaves valid ones alone.

## Verification and monitoring

Prove behavior with real handshakes, not file timestamps. `certificate-verify-peer.sh HOST PORT CA_FILE CLIENT_CERT CLIENT_KEY` checks the server's chain and name, admits the stack's client, rejects an anonymous one, and prints the served leaf's serial and fingerprint; run it against every internal listener. A client-facing listener requires no client certificate, so check it instead with a TLS client that presents none and verifies the chain and the name the proxy dials. Beyond it, exercise on the internal listeners:

- an untrusted and an expired client certificate, and a wrong server hostname, all refused;
- a renewal: a changed serial on a fresh connection without restarting the process;
- a mismatched publication, renewer and application restarts, CA downtime, connection draining, and an overlapping CA rotation.

Monitor renewal errors in the renewers' logs, reload failures in the applications', the renewer's health, and each leaf's remaining lifetime, alerting well before the shortest leaf could expire during a CA outage.
