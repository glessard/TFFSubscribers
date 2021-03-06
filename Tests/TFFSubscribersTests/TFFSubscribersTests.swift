import XCTest
import Combine

import TFFSubscribers

final class TFFSubscribersTests: XCTestCase
{
  func testTimedSink()
  {
    let p = Just(1).append(Just(2)).append(Just(3))

    let e = expectation(description: #function)
    let s = TimedSink(
      upstream: p,
      qos: .utility,
      interval: .milliseconds(10),
      autostart: false,
      receive: { _ in },
      completion: {
        c in
        XCTAssertEqual(c, .finished)
        e.fulfill()
      }
    )

    let start = Date()
    s.initiateReceiving()
    waitForExpectations(timeout: 1.0)
    XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.02)
  }
}
