---
max_turns: 45
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [temporal, mtls, workers]
---

The billing service has a Temporal workflow that reconciles a payment and asks accounts to update a subscription. The workflow may run for days and must continue after the initiating user's session expires. Billing owns payment rows; accounts owns subscription rows. Both services and the self-hosted Temporal frontend require client certificates. Billing's deployment supplies distinct files for service-network and Temporal credentials.

Write focused Swift excerpts under ./acme-billing for worker Run composition (at Sources/Billing/Worker/Run.swift), the Activity container, its Core Activity-service port, and the accounts gRPC consumer adapter. Show the receiving internal handler/use-case boundary under ./acme-accounts. Assume the workflow and generated AccountInternalService contracts already exist; registration IDs and idempotency keys are available in Activity inputs. Include the configuration scopes and reload lifecycle, and summarize what is persisted in workflow history versus constructed at worker startup. No complete package scaffold, dependency resolution, or execution is needed.
