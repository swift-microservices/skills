#!/bin/sh
# Publish a renewed leaf into a workload's directory: verify that it chains to the directory's
# trust and pairs with the directory's key, then replace cert.pem atomically. Renewal keeps the
# private key, so only the certificate changes.
# Usage: certificate-publish.sh NEW_CERT CERT_DIR
set -euo pipefail
new_cert=${1:?usage: certificate-publish.sh NEW_CERT CERT_DIR}
cert_dir=${2:?usage: certificate-publish.sh NEW_CERT CERT_DIR}

fail() { echo "certificate-publish: $*" >&2; exit 1; }

step certificate verify "$new_cert" --roots "$cert_dir/ca.pem" \
  || fail "$new_cert does not verify against $cert_dir/ca.pem"
[ "$(step certificate key "$new_cert")" = "$(step crypto key public "$cert_dir/key.pem")" ] \
  || fail "$new_cert does not match $cert_dir/key.pem"

# The temporary file lives in the target directory: rename is atomic only within one filesystem,
# so a reader sees the old certificate or the new one, never a partial file.
umask 027
temporary=$(mktemp "$cert_dir/.cert.pem.XXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM
cp "$new_cert" "$temporary"
chmod 0644 "$temporary"
mv -f "$temporary" "$cert_dir/cert.pem"
