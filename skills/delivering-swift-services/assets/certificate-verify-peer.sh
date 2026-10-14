#!/usr/bin/env bash
# Probe one mTLS listener with real handshakes. Run from a container on the stack's private
# network that has curl and openssl, mounting a client credential directory read-only.
# Usage: certificate-verify-peer.sh HOST PORT CA_FILE CLIENT_CERT CLIENT_KEY
#   HOST is the name clients dial; the server's certificate must carry it as a DNS SAN.
#
# Passes when:
#   1. the server's chain verifies against CA_FILE and its certificate matches HOST;
#   2. a request presenting CLIENT_CERT/CLIENT_KEY receives an HTTP/2 response;
#   3. a request presenting no client certificate receives none.
# Prints the served leaf's serial, fingerprint, and expiry: compare them before and after a
# renewal to prove a fresh connection got the new leaf.
set -euo pipefail
host=${1:?usage: certificate-verify-peer.sh HOST PORT CA_FILE CLIENT_CERT CLIENT_KEY}
port=${2:?usage: certificate-verify-peer.sh HOST PORT CA_FILE CLIENT_CERT CLIENT_KEY}
ca_file=${3:?usage: certificate-verify-peer.sh HOST PORT CA_FILE CLIENT_CERT CLIENT_KEY}
client_cert=${4:?usage: certificate-verify-peer.sh HOST PORT CA_FILE CLIENT_CERT CLIENT_KEY}
client_key=${5:?usage: certificate-verify-peer.sh HOST PORT CA_FILE CLIENT_CERT CLIENT_KEY}

for tool in curl openssl; do
  command -v "$tool" >/dev/null || { echo "certificate-verify-peer: $tool is required" >&2; exit 1; }
done

# 1. Server identity: chain and name, with the client pair offered as a real client would.
if ! handshake=$(openssl s_client -connect "$host:$port" -servername "$host" \
  -CAfile "$ca_file" -verify_hostname "$host" -verify_return_error \
  -cert "$client_cert" -key "$client_key" -alpn h2 </dev/null 2>&1); then
  printf '%s\n' "$handshake" >&2
  echo "FAIL $host:$port: server chain or name did not verify" >&2
  exit 1
fi
printf '%s\n' "$handshake" | openssl x509 -noout -serial -fingerprint -sha256 -enddate

# 2 and 3. Admission: an HTTP/2 status means the server accepted the handshake; 000 means it
# did not answer. curl's exit status is not the signal (a gRPC listener may reset a plain GET).
status() {
  curl --silent --http2 --max-time 5 --cacert "$ca_file" \
    --output /dev/null --write-out '%{http_code}' "$@" "https://$host:$port/" 2>/dev/null || :
}
with_certificate=$(status --cert "$client_cert" --key "$client_key")
without_certificate=$(status)

if [[ -z $with_certificate || $with_certificate == 000 ]]; then
  echo "FAIL $host:$port: rejected a client certificate the stack's CA signed" >&2
  exit 1
fi
if [[ -n $without_certificate && $without_certificate != 000 ]]; then
  echo "FAIL $host:$port: answered a client with no certificate (HTTP $without_certificate)" >&2
  exit 1
fi
echo "PASS $host:$port: verified server, admitted the stack's client, rejected an anonymous one"
