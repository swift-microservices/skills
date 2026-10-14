---
type: llm
---

PASS if the reply says migrations must be expand/contract: additive changes (new tables, nullable columns, indexes) ship freely, while renames, drops, and tightened constraints wait for a later commit once no deployed code uses the old shape, because the old build runs against the new schema during a deploy and after a rollback.
FAIL if it relies on down migrations or reverting the schema when rolling back, or allows a rename or drop in the same deploy as the code that stops using the old shape.
