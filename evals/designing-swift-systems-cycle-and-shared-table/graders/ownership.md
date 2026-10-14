---
type: llm
focus: { source: file, path: untangle.md }
---

PASS if the proposal gives `stock_reservations` exactly one owning module (Inventory, or a new module that owns stock), and the other module stops writing or reading that table and instead asks the owner through a port declared in its own Core (for example releasing a reservation on cancellation).

FAIL if both modules keep writing the table, Orders reads or joins it, the proposal shares it through a view, a shared repository, or a common target, or ownership is left undecided without being raised as a decision.
