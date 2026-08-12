//
// Copyright (c) Vatsal Manot
//

@testable import Merge

import Swallow
import Testing

@Suite
struct PublisherExtensionsTests {
    @Test
    func testEitherPublisher() {
        enum TestError: Hashable, Error {
            case some
        }

        var foo = true

        #expect(
            Either {
                if foo {
                    Just("foo").setFailureType(to: TestError.self)
                } else {
                    Fail<String, TestError>(error: TestError.some)
                }
            }
            .subscribeAndWaitUntilDone() == .success("foo")
        )

        foo = false

        #expect(
            Either {
                if foo {
                    Just("foo").setFailureType(to: TestError.self)
                } else {
                    Fail<String, TestError>(error: TestError.some)
                }
            }
            .subscribeAndWaitUntilDone() == .failure(TestError.some)
        )
    }

    @Test
    func testWhilePublisher() {
        var count = 0

        Publishers.While(count < 100) {
            Just(()).then {
                count += 1
            }
        }
        .reduceAndMapTo(())
        .subscribeAndWaitUntilDone()

        #expect(count == 100)

        enum TestError: Hashable, Error {
            case some
        }

        #expect(
            Publishers.While(true) {
                Fail<Void, TestError>(error: TestError.some)
            }
            .reduceAndMapTo("foo")
            .subscribeAndWaitUntilDone() == .failure(TestError.some)
        )
    }
}
