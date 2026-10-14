#!/bin/sh
# Keep one workload's leaf fresh: renew before expiry into a private directory, then let
# certificate-publish.sh verify and swap it in. Runs forever beside the application, in a
# step-cli container as RENEWER_UID:APP_GID; failures retry while the application keeps using
# the last valid leaf.
#
# Environment:
#   CA_URL                  the CA's private address, e.g. https://ca:9000
#   CERT_DIR                the workload's directory (cert.pem, key.pem, ca.pem), read-write
#   PRIVATE_DIR             a renewer-only 0700 tmpfs for the unpublished certificate
#   RENEW_BEFORE            remaining lifetime that triggers renewal, e.g. 8h or 33%
#   CHECK_INTERVAL_SECONDS  seconds between checks
#   CA_ROOT_FILE            optional; trust for the CA endpoint (default: CERT_DIR/ca.pem)
#   PUBLISH_SCRIPT          optional; default: certificate-publish.sh beside this script
set -euo pipefail
: "${CA_URL:?set CA_URL to the CA's private address}"
: "${CERT_DIR:?set CERT_DIR to the workload's credential directory}"
: "${PRIVATE_DIR:?set PRIVATE_DIR to the renewer-only tmpfs}"
: "${RENEW_BEFORE:?set RENEW_BEFORE, e.g. 8h or 33%}"
: "${CHECK_INTERVAL_SECONDS:?set CHECK_INTERVAL_SECONDS}"
ca_root=${CA_ROOT_FILE:-$CERT_DIR/ca.pem}
publish=${PUBLISH_SCRIPT:-$(dirname "$0")/certificate-publish.sh}

for file in cert.pem key.pem ca.pem; do
  if [ ! -r "$CERT_DIR/$file" ]; then
    echo "certificate-renew: $CERT_DIR/$file is missing; run the enrollment one-shot first" >&2
    exit 1
  fi
done
[ -r "$publish" ] || { echo "certificate-renew: cannot read $publish" >&2; exit 1; }

while :; do
  status=0
  step certificate needs-renewal "$CERT_DIR/cert.pem" --expires-in "$RENEW_BEFORE" || status=$?
  case $status in
    0)
      if step ca renew "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" \
        --ca-url "$CA_URL" --root "$ca_root" \
        --out "$PRIVATE_DIR/next-cert.pem" --force; then
        if sh "$publish" "$PRIVATE_DIR/next-cert.pem" "$CERT_DIR"; then
          echo "certificate-renew: published $(step certificate inspect "$CERT_DIR/cert.pem" --short)"
        else
          echo "certificate-renew: publication failed; retrying in ${CHECK_INTERVAL_SECONDS}s" >&2
        fi
      else
        echo "certificate-renew: renewal failed; retrying in ${CHECK_INTERVAL_SECONDS}s" >&2
      fi
      ;;
    1) ;;  # not due yet
    *) echo "certificate-renew: cannot evaluate $CERT_DIR/cert.pem (exit $status)" >&2 ;;
  esac
  sleep "$CHECK_INTERVAL_SECONDS"
done
