//
// Copyright (c) Vatsal Manot
//

@testable import Merge

import Swallow
import Testing

@Suite
struct PassthroughTaskTests {
    @Test
    func testStatus() async throws {
        let gate = AsyncStream<Void>.makeStream()
        let task = PassthroughTask<Int, Error>(priority: nil) {
            for await _ in gate.stream {
                break
            }

            return 69
        }

        #expect(task.status == .inactive)

        task.start()

        #expect(task.status == .active)

        gate.continuation.yield(())
        gate.continuation.finish()

        let value = try await task.value

        #expect(value == 69)
    }
}
