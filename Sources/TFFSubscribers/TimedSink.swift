import Combine
import Dispatch
import CurrentQoS

public class TimedSink<Upstream: Publisher, Context: Scheduler>
{
  public typealias Input =   Upstream.Output
  public typealias Failure = Upstream.Failure

  public let combineIdentifier = CombineIdentifier()

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
  }
}

extension TimedSink where Context == DispatchQueue
{
  public convenience init(upstream: Upstream,
                          qos: DispatchQoS = .current,
                          interval: Context.SchedulerTimeType.Stride,
                          autostart: Bool = true,
                          receive: @escaping (Input) -> Void,
                          completion: @escaping(Subscribers.Completion<Failure>) -> Void = { _ in })
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(upstream: upstream, context: queue, completion: completion, receive: receive, interval: interval, autostart: autostart)
  }
}

extension TimedSink: Subscriber, Cancellable
{
  public func receive(subscription: Subscription)
  {
    self.subscription = subscription
    subscription.request(start ? .max(1) : .none)
  }

  public func receive(_ input: Input) -> Subscribers.Demand
  {
    present(input)
    if let sub = subscription
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

  public func initiateReceiving()
  {
    guard start == false else { return }

    scheduler.schedule {
      if let sub = self.subscription
      {
        sub.request(.max(1))
        self.start = true
      }
    }
  }

  public func cancel()
  {
    scheduler.schedule {
      self.subscription?.cancel()
      self.subscription = nil
    }
  }
}
