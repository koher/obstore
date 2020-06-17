import Combine
import Dispatch

private let queue: DispatchQueue = .init(label: "org.koherent.Obstore.Store")

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public final class Store<Value: Identifiable> {
    private let get: (Value.ID) throws -> Value?
    private var updateCancellable: AnyCancellable?

    private var observedValues: [Value.ID: Weak<(CurrentValueObserved<Value>)>] = [:]
    
    public init(get: @escaping (Value.ID) throws -> Value?, update: AnyPublisher<Value, Never>) {
        self.get = get
        
        updateCancellable = update.sink { value in
            queue.async { [weak self] in
                guard let self = self else { return }
                guard let weakValue = self.observedValues[value.id] else { return }
                guard let observedValue = weakValue.value else {
                    self.observedValues.removeValue(forKey: value.id)
                    return
                }
                observedValue.value = value
            }
        }
    }
    
    public func value(for id: Value.ID) throws -> Observed<Value>? {
        try queue.sync {
            try valueWithoutSync(for: id)
        }
    }
    
    private func valueWithoutSync(for id: Value.ID) throws -> Observed<Value>? {
        if let weakValue = observedValues[id] {
            if let value = weakValue.value {
                return value
            } else {
                observedValues.removeValue(forKey: id)
            }
        }
        
        guard let value = try get(id) else { return nil }
        
        let observedValue = CurrentValueObserved(CurrentValueSubject(value))
        observedValues[id] = Weak(observedValue)
        return observedValue
    }
    
    public func values<IDS: Collection>(for ids: IDS) throws -> Observed<[Value]> where IDS.Element == Value.ID {
        try queue.sync {
            let observedValues: [Observed<Value>] = try ids.compactMap { id in try valueWithoutSync(for: id) }
            return CombinedObserved(observedValues)
        }
    }
}
