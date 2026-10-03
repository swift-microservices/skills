import LibraryCore
import Testing
@Test("Budget includes initial request and stops when exhausted")
func budgetBoundary() throws {
    let budget = try RetryBudget(maximumAttempts: 2)
    #expect(budget.permitsAttempt(after: 0))
    #expect(budget.permitsAttempt(after: 1))
    #expect(!budget.permitsAttempt(after: 2))
}
@Test("Invalid budgets are refused", arguments: [0, -1])
func invalidBudget(_ attempts: Int) {
    #expect(throws: RetryBudget.InvalidBudget.self) { try RetryBudget(maximumAttempts: attempts) }
}
