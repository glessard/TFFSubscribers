import Combine
import Dispatch

public class TimedSink<Input, Failure: Error>: Subscriber, Cancellable
{
  public let combineIdentifier = CombineIdentifier()

  private let lock = Lock()
  private var subscription: Subscription?
  private let q = DispatchQueue(label: "timed-requests", qos: .background)

  private let present: (Input) -> Void
  private let finally: (Subscribers.Completion<Failure>) -> Void
  private let gap: DispatchTimeInterval

  public init(completion: @escaping (Subscribers.Completion<Failure>) -> Void = { _ in },
              receive: @escaping (Input) -> Void,
              interval: DispatchTimeInterval = .seconds(1))
  {
    finally = completion
    present = receive
    gap = interval
  }

  deinit {
    subscription?.cancel()
    lock.clean()
  }

  public func receive(subscription: Subscription)
  {
    lock.lock()
    self.subscription = subscription
    lock.unlock()
    subscription.request(.max(1))
  }

  public func receive(_ input: Input) -> Subscribers.Demand
  {
    present(input)
    lock.lock()
    let sub = subscription
    lock.unlock()
    if let sub = sub
    {
      q.schedule(after: .init(.now() + gap), tolerance: .init(gap)) { sub.request(.max(1)) }
    }
    return .none
  }

  public func receive(completion: Subscribers.Completion<Failure>)
  {
    cancel()
    finally(completion)
  }

  public func cancel()
  {
    lock.lock()
    let sub = subscription
    subscription = nil
    lock.unlock()
    sub?.cancel()
  }
}
