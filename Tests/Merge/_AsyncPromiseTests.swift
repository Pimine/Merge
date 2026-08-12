//
// Copyright (c) Vatsal Manot
//

@testable import Merge

import Dispatch
import Testing

@Suite("AsyncPromise")
struct _AsyncPromiseTests {
    private enum ExpectedError: Error {
        case failure
    }

    @Test("Concurrent fulfillment reliably resumes a waiter")
    func concurrentFulfillmentStress() async {
        for _ in 0..<100 {
            let promise = _AsyncPromise<Int, Never>()
            Task.detached { promise.fulfill(with: 1) }
            #expect(await promise.get() == 1)
        }
    }

    @Test("Failure preserves its concrete error")
    func failurePreservesError() async {
        let promise = _AsyncPromise<Int, ExpectedError>()
        promise.fulfill(throwing: .failure)

        await #expect(throws: ExpectedError.self) {
            try await promise.get()
        }
    }

    @Test("Async initializers propagate success and failure")
    func asyncInitializersPropagateResults() async throws {
        let success = _AsyncPromise<Int, Error> { 100 }
        let failure = _AsyncPromise<Int, Error> { throw ExpectedError.failure }

        #expect(try await success.get() == 100)
        await #expect(throws: ExpectedError.self) {
            try await failure.get()
        }
    }

    @Test("Continuation initializer resumes the promise")
    func continuationInitializerResumes() async throws {
        let promise = _AsyncPromise<String, Error> { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: "continued")
            }
        }

        #expect(try await promise.get() == "continued")
    }

    @Test("One fulfillment resumes every concurrent waiter")
    func fulfillmentResumesEveryWaiter() async {
        let promise = _AsyncPromise<Int, Never>()
        let waiters = (0..<10).map { _ in Task { await promise.get() } }

        promise.fulfill(with: 999)

        for waiter in waiters {
            #expect(await waiter.value == 999)
        }
    }
}
