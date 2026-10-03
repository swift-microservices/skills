import ArgumentParser
import LibraryCore

@main
struct ExampleService: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "example-service", subcommands: [Serve.self])
}

struct Serve: ParsableCommand {
    func run() throws {
        let budget = try RetryBudget(maximumAttempts: 2)
        print("Configured retry attempts: \(budget.maximumAttempts)")
    }
}
