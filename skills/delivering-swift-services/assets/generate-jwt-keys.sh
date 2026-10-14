#!/usr/bin/env bash
# Generate the Ed25519 pair that signs access tokens, as PEM files in a private directory.
# Usage: generate-jwt-keys.sh DIRECTORY
#
# Only the authenticating service mounts jwt-private.pem; every service that verifies tokens
# mounts jwt-public.pem; workers mount neither. Configuration carries the path, never the key.
# Refuses to overwrite: rotating invalidates every access token in flight, so move the old pair
# away deliberately, run this again, and restart every service.
set -euo pipefail
umask 077

directory=${1:?usage: generate-jwt-keys.sh DIRECTORY}
private_key="$directory/jwt-private.pem"
public_key="$directory/jwt-public.pem"

command -v openssl >/dev/null || { echo 'generate-jwt-keys: openssl is required' >&2; exit 1; }

if [[ -e $private_key || -e $public_key ]]; then
  echo "generate-jwt-keys: $directory already holds a key pair; move it away to rotate" >&2
  exit 1
fi

mkdir -p "$directory"
chmod 0700 "$directory"
openssl genpkey -algorithm ed25519 -out "$private_key"
openssl pkey -in "$private_key" -pubout -out "$public_key"
chmod 0600 "$private_key"
chmod 0644 "$public_key"

echo "Wrote $private_key (the authenticating service alone) and $public_key."
echo "Keep $directory out of version control. The private key must be readable by the image's"
echo "numeric user where it is mounted (for example: chown APP_UID $private_key)."
