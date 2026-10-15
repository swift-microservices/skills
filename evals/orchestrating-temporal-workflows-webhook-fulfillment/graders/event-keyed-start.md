---
type: regex
target: { source: file, path: acme-billing/Sources/BillingWorkflows/Fulfillment/TemporalFulfillmentWorkflowClient.swift }
pattern: '^(?![\s\S]*UUID\(\))(?=[\s\S]*\.allowDuplicateFailedOnly)(?=[\s\S]*\.useExisting)[\s\S]*[Ee]xecutionTimeout'
---
