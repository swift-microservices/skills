---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
tags: [delivering, negative]
---

In our Swift service, CreateSubscriberUseCase throws .duplicateEmail even when the email is new. Here's the use case body — what's wrong with the catch ordering?

```swift
do {
    return try await database.withTransaction { scope in
        try await scope.subscriberRepository.create(command)
    }
} catch {
    throw .duplicateEmail
}
```
