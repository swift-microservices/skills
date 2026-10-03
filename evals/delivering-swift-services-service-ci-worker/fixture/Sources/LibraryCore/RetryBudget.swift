//
//  RetryBudget.swift
//  ExampleService
//
//  Created by Example Maintainer on 10/4/26.
//

/// A retry budget including the initial request.
public struct RetryBudget: Sendable {
    public enum InvalidBudget: Error { case nonPositive }
    public let maximumAttempts: Int
    public init(maximumAttempts: Int) throws {
        guard maximumAttempts > 0 else { throw InvalidBudget.nonPositive }
        self.maximumAttempts = maximumAttempts
    }
    /// Whether another attempt is allowed after the given completed attempts.
    public func permitsAttempt(after completedAttempts: Int) -> Bool {
        completedAttempts >= 0 && completedAttempts < maximumAttempts
    }
}
