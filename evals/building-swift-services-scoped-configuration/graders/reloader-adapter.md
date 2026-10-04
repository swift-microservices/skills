---
type: llm
focus: { source: file, path: acme-catalog/Sources/Catalog/Configuration/TimedCertificateReloader.Configuration+ConfigReader.swift }
---

PASS if the extension adds an initializer that takes only a `ConfigReader`, reads relative keys (`certificatePath`, `privateKeyPath`, and a unit-suffixed refresh interval such as `refreshIntervalSeconds`), and contains no hard-coded mount path, so the same initializer works with `tls` and `temporal.tls` readers.

FAIL if it takes a default-path, directory, logger, or scope-selecting argument, or embeds a `/run/...` path.
