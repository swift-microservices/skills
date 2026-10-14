---
type: llm
focus: { source: file, path: acme-library/Sources/LoansCore/Loans/UseCases/BorrowBook/BorrowBookUseCase.swift }
---

PASS if all of these hold:
- The use case takes `subject: UserIdentity` and is generic over a `Database` whose scope adopts its use-case scope.
- It learns the member's standing through a protocol owned by the loans module (a port such as a member or membership client, declared in LoansCore), injected through its initializer, and refuses a suspended member with its own typed error.
- It imports no Members target and names no Members type.
- It calls the port outside `database.withTransaction`, not inside the closure.

FAIL if the file imports `MembersCore` or any other Members target, names a Members use case or entity, calls the port inside the transaction closure, reads `OperationContext`, or leaves the suspension check to a handler.
