#!/bin/sh
# One-shot first enrollment of one workload's credential directory, with a single-use token
# minted offline. Runs in a step-cli container as the renewer's user (RENEWER_UID:APP_GID).
#
# Environment:
#   WORKLOAD_NAME  the subject the token was minted for (the provisioner template fixes the SANs)
#   CA_URL         the CA's private address, e.g. https://ca:9000
#   CA_ROOT_FILE   the environment's root certificate, verified out of band
#   TOKEN_FILE     the enrollment token file (valid minutes, used once)
#   CERT_DIR       the workload's directory; receives cert.pem, key.pem, ca.pem
#
# Exits 0 without contacting the CA when the directory already holds a leaf that verifies:
# renewal keeps it fresh. An expired or broken leaf needs a deliberate re-enrollment.
set -euo pipefail
: "${WORKLOAD_NAME:?set WORKLOAD_NAME to the workload's subject}"
: "${CA_URL:?set CA_URL to the CA's private address}"
: "${CA_ROOT_FILE:?set CA_ROOT_FILE to the environment's root certificate}"
: "${CERT_DIR:?set CERT_DIR to the workload's credential directory}"

fail() { echo "certificate-enroll: $*" >&2; exit 1; }

[ -d "$CERT_DIR" ] && [ -w "$CERT_DIR" ] || fail "$CERT_DIR is not a writable directory; run permission-init first"
[ -r "$CA_ROOT_FILE" ] || fail "cannot read $CA_ROOT_FILE"

if [ -e "$CERT_DIR/cert.pem" ] || [ -e "$CERT_DIR/key.pem" ]; then
  if step certificate verify "$CERT_DIR/cert.pem" --roots "$CA_ROOT_FILE"; then
    echo "certificate-enroll: $CERT_DIR already holds a valid leaf for $WORKLOAD_NAME"
    exit 0
  fi
  fail "$CERT_DIR holds a leaf that does not verify; move it away and re-enroll with a fresh token"
fi

: "${TOKEN_FILE:?set TOKEN_FILE to the enrollment token file}"
[ -r "$TOKEN_FILE" ] || fail "cannot read $TOKEN_FILE; mint a fresh token offline"

umask 027
step ca certificate "$WORKLOAD_NAME" "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" \
  --token "$(cat "$TOKEN_FILE")" \
  --ca-url "$CA_URL" \
  --root "$CA_ROOT_FILE"
cp "$CA_ROOT_FILE" "$CERT_DIR/ca.pem"

step certificate verify "$CERT_DIR/cert.pem" --roots "$CERT_DIR/ca.pem" \
  || fail "the issued leaf does not verify against $CA_ROOT_FILE"
chmod 0640 "$CERT_DIR/key.pem"
chmod 0644 "$CERT_DIR/cert.pem" "$CERT_DIR/ca.pem"
step certificate inspect "$CERT_DIR/cert.pem" --short
echo "certificate-enroll: enrolled $WORKLOAD_NAME; delete the token and this one-shot"
