import Testing
import UtilityAdapter
import UtilityCore

private final class ContractState { var count = 0 }
private enum ContractFailure: Error { case expected }

private actor ContractCaller {
    private let state = ContractState()

    func exercise(_ runner: any OperationRunner) async throws -> Int {
        let result = await runner.run {
            self.assertIsolated()
            state.count += 1
            await Task.yield()
            self.assertIsolated()
            return state.count
        }
        #expect(result == 1)
        do {
            let _: Int = try await runner.run {
                self.assertIsolated()
                state.count += 1
                await Task.yield()
                self.assertIsolated()
                throw ContractFailure.expected
            }
            Issue.record("The operation error was swallowed")
        } catch ContractFailure.expected {
            #expect(state.count == 2)
        }
        return state.count
    }
}

@Test private func contractCustomActor() async throws {
    #expect(try await ContractCaller().exercise(InlineRunner()) == 2)
}

@Test @MainActor private func contractMainActor() async throws {
    let state = ContractState()
    let runner: any OperationRunner = InlineRunner()
    let value = await runner.run {
        MainActor.assertIsolated()
        state.count += 1
        await Task.yield()
        MainActor.assertIsolated()
        return state.count
    }
    #expect(value == 1)
    #expect(state.count == 1)
}

@Test private func contractPublicAPI() {
    let record: Record = InlineRunner().record(value: 42)
    #expect(record == Record(value: 42))
}
