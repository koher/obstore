import Combine
import Dispatch

private let queue: DispatchQueue = .init(label: "org.koherent.Obstore.Store")

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public final class Store<Value: Identifiable> {
    private let dataSource: AnyStoreDataSource<Value>
    
    private var updateCancellable: AnyCancellable?
    private var observedValues: [Value.ID: Weak<(CurrentValueObserved<Value>)>] = [:]
    
    public init<DS: StoreDataSource>(_ dataSource: DS) where DS.Value == Value {
        self.dataSource = AnyStoreDataSource(dataSource)
        
        updateCancellable = dataSource.publisher.sink { [weak self] value in
            guard let self = self else { return }
            queue.sync {
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
        
        guard let value = try dataSource.value(for: id) else { return nil }
        
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

public protocol StoreDataSource {
    associatedtype Value: Identifiable
    
    func value(for id: Value.ID) throws -> Value?
    var publisher: AnyPublisher<Value, Never> { get }
}

internal struct AnyStoreDataSource<Value: Identifiable>: StoreDataSource {
    private let valueFor: (Value.ID) throws -> Value?
    let publisher: AnyPublisher<Value, Never>
    
    init<DS: StoreDataSource>(_ source: DS) where DS.Value == Value {
        self.valueFor = { id in try source.value(for: id) }
        self.publisher = source.publisher
    }
    
    func value(for id: Value.ID) throws -> Value? {
        try valueFor(id)
    }
}
