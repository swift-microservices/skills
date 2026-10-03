//
//  ExampleService.swift
//  ExampleService
//
//  Created by Example Maintainer on 10/4/26.
//

import ArgumentParser
import LibraryCore

@main
struct ExampleService: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "example-service", subcommands: [Serve.self, Worker.self])
}

struct Serve: ParsableCommand {
    func run() throws {
        let budget = try RetryBudget(maximumAttempts: 2)
        print("Configured retry attempts: \(budget.maximumAttempts)")
    }
}

struct Worker: ParsableCommand {
    static let configuration = CommandConfiguration(subcommands: [Run.self])
    struct Run: ParsableCommand {
        func run() { print("Worker command configured") }
    }
}
