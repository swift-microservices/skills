---
type: llm
focus: { source: file, path: stack/.env.example }
---

PASS if this file names the variables the stack needs (image tags, database owner and role passwords for accounts and orders including the worker's role, the paths of the JWT key and CA files, the Tailscale auth key) with secret values left empty or as obvious placeholders, and contains no key material.
FAIL if it holds a private key, certificate, or token body, or a real-looking password, or omits the database passwords.
