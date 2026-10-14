#!/bin/sh
# Local development only: a throwaway root that issues every workload's leaf directly, so a
# local stack keeps mTLS with the same files, paths, and verification as a deployed one. Its root
# key lives in the local volume; never trust this root anywhere else.
# Runs as a one-shot in a step-cli container. Set FILE_OWNER (RENEWER_UID:APP_GID) when it runs
# as root on fresh volumes: each directory is then handed to that owner, group-readable, setgid.
# Usage: certificate-local-ca.sh CA_DIR LEAF_LIFETIME NAMES CERT_DIR [NAMES CERT_DIR ...]
#   CA_DIR         directory holding the local root (created on first run)
#   LEAF_LIFETIME  leaf validity, e.g. 720h; rerun to reissue a leaf that expired
#   NAMES          comma-separated DNS SANs, the first the subject (e.g. users,localhost)
#   CERT_DIR       that workload's directory; receives cert.pem, key.pem, ca.pem
set -euo pipefail
usage='usage: certificate-local-ca.sh CA_DIR LEAF_LIFETIME NAMES CERT_DIR [NAMES CERT_DIR ...]'
ca_dir=${1:?$usage}
lifetime=${2:?$usage}
shift 2
if [ $# -lt 2 ] || [ $(($# % 2)) -ne 0 ]; then
  echo "certificate-local-ca: $usage" >&2
  exit 1
fi

umask 027
mkdir -p "$ca_dir"
if [ ! -f "$ca_dir/root.pem" ]; then
  step certificate create "Local Development Root" "$ca_dir/root.pem" "$ca_dir/root.key" \
    --profile root-ca --no-password --insecure
fi

while [ $# -gt 0 ]; do
  names=$1
  cert_dir=$2
  shift 2
  subject=${names%%,*}
  if [ -f "$cert_dir/cert.pem" ] \
    && step certificate verify "$cert_dir/cert.pem" --roots "$ca_dir/root.pem" >/dev/null 2>&1; then
    echo "certificate-local-ca: $subject already holds a valid leaf"
    continue
  fi
  sans=''
  for name in $(echo "$names" | tr ',' ' '); do
    sans="$sans --san $name"
  done
  # shellcheck disable=SC2086 # one --san flag per name
  step certificate create "$subject" "$cert_dir/cert.pem" "$cert_dir/key.pem" \
    --profile leaf --ca "$ca_dir/root.pem" --ca-key "$ca_dir/root.key" \
    $sans --not-after "$lifetime" --no-password --insecure --force
  cp "$ca_dir/root.pem" "$cert_dir/ca.pem"
  chmod 0640 "$cert_dir/key.pem"
  chmod 0644 "$cert_dir/cert.pem" "$cert_dir/ca.pem"
  if [ -n "${FILE_OWNER:-}" ]; then
    chown "$FILE_OWNER" "$cert_dir" "$cert_dir/cert.pem" "$cert_dir/key.pem" "$cert_dir/ca.pem"
    chmod 2750 "$cert_dir"
  fi
  echo "certificate-local-ca: issued $subject ($names) for $lifetime"
done
