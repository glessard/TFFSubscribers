import XCTest
import Combine

import TFFSubscribers

final class TFFSubscribersTests: XCTestCase
{
  func testTimedSink()
  {
    let p = Just(1).append(Just(2)).append(Just(3))

    let e = expectation(description: #function)
    let s = TimedSink<Int, Never>(
      completion: {
        c in
        XCTAssertEqual(c, .finished)
        e.fulfill()
      },
      receive: { _ in },
      interval: .milliseconds(10)
    )

    let start = Date()
    p.subscribe(s)
    waitForExpectations(timeout: 1.0)
    XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.02)
  }
}
