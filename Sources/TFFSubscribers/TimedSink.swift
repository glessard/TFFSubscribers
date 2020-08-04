import Combine
import Dispatch
import CurrentQoS

public class TimedSink<Upstream: Publisher, Context: Scheduler>
{
  public typealias Input =   Upstream.Output
  public typealias Failure = Upstream.Failure

  public let combineIdentifier = CombineIdentifier()

  private let lock = Lock()
  private var subscription: Subscription?

  private let scheduler: Context
  private let present: (Input) -> Void
  private let finally: (Subscribers.Completion<Failure>) -> Void
  private let gap: Context.SchedulerTimeType.Stride
  private var start: Bool

  public init(upstream: Upstream,
              context: Context,
              completion: @escaping (Subscribers.Completion<Failure>) -> Void = { _ in },
              receive: @escaping (Input) -> Void,
              interval: Context.SchedulerTimeType.Stride,
              autostart: Bool = true)
  {
    scheduler = context
    finally = completion
    present = receive
    gap = interval
    start = autostart

    upstream.receive(on: context).subscribe(self)
  }

  deinit {
    subscription?.cancel()
    lock.clean()
  }
}

extension TimedSink where Context == DispatchQueue
{
  public convenience init(upstream: Upstream, qos: DispatchQoS = .current,
                          completion: @escaping(Subscribers.Completion<Failure>) -> Void = { _ in },
                          receive: @escaping (Input) -> Void,
                          interval: Context.SchedulerTimeType.Stride,
                          autostart: Bool = true)
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(upstream: upstream, context: queue, completion: completion, receive: receive, interval: interval, autostart: autostart)
  }
}

extension TimedSink: Subscriber, Cancellable
{
  public func receive(subscription: Subscription)
  {
    lock.lock()
    self.subscription = subscription
    lock.unlock()
    subscription.request(start ? .max(1) : .none)
  }

  public func receive(_ input: Input) -> Subscribers.Demand
  {
    present(input)
    lock.lock()
    let sub = subscription
    lock.unlock()
    if let sub = sub
    {
      scheduler.schedule(after: scheduler.now.advanced(by: gap)) { sub.request(.max(1)) }
    }
    return .none
  }

  public func receive(completion: Subscribers.Completion<Failure>)
  {
    cancel()
    finally(completion)
  }

  public func startReceiving()
  {
    guard start == false else { return }

    scheduler.schedule {
      [self] in
      if let sub = subscription
      {
        sub.request(.max(1))
        start = true
      }
    }
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
