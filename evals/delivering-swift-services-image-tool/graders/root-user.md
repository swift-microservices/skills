---
type: llm
---

PASS if the reply addresses that swift-container-plugin images run as root by default, and either sets a non-root user through the plugin or base image (confirmed with an image inspection), or treats the root image as a project exception: it records it in AGENTS.md, or tells the user to record it there (the prompt asks what to record), together with a compensating control such as read-only mounts and file ownership, and the image check is told to allow it (for example `ALLOW_ROOT_IMAGE=true` or an `allow_root_image` input).
FAIL if the reply ignores the image's user, or the image check accepts root without the reply naming the exception that must be recorded.
