import Combine
import Dispatch

private let queue: DispatchQueue = .init(label: "org.koherent.Obstore.Store")

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public final class Store<Value: Identifiable> {
    private let dataSource: AnyStoreDataSource<Value>
    
    private var updateCancellable: AnyCancellable?
    private var observedValues: [Value.ID: Weak<(CurrentValueObserved<Value?>)>] = [:]
    
    public init<DS: StoreDataSource>(_ dataSource: DS) where DS.Value == Value {
        self.dataSource = AnyStoreDataSource(dataSource)
        
        updateCancellable = dataSource.publisher.sink { [weak self] idAndValue in
            guard let self = self else { return }
            let (id, value) = idAndValue
            queue.sync {
                guard let weakValue = self.observedValues[id] else { return }
                guard let observedValue = weakValue.value else {
                    self.observedValues.removeValue(forKey: id)
                    return
                }
                observedValue.value = value
            }
        }
    }
    
    public func value(for id: Value.ID) throws -> Observed<Value?> {
        try queue.sync {
            try valueWithoutSync(for: id)
        }
    }
    
    private func valueWithoutSync(for id: Value.ID) throws -> Observed<Value?> {
        if let weakValue = observedValues[id] {
            if let value = weakValue.value {
                return value
            } else {
                observedValues.removeValue(forKey: id)
            }
        }
        
        let observedValue: CurrentValueObserved<Value?>
        if let value = try dataSource.value(for: id) {
            observedValue = CurrentValueObserved(CurrentValueSubject(value))
        } else {
            observedValue = CurrentValueObserved(CurrentValueSubject(nil))
            observedValues[id] = Weak(observedValue)
            return observedValue
            
        }
        observedValues[id] = Weak(observedValue)
        return observedValue
    }
    
    public func values<IDS: Collection>(for ids: IDS) throws -> Observed<[Value]> where IDS.Element == Value.ID {
        try queue.sync {
            let observedValues: [Observed<Value?>] = try ids.map { id in try valueWithoutSync(for: id) }
            return CombinedObserved(observedValues)
        }
    }
}

public protocol StoreDataSource {
    associatedtype Value: Identifiable
    associatedtype ValuePublisher: Publisher
        where ValuePublisher.Output == (Value.ID, Value?), ValuePublisher.Failure == Never
    
    func value(for id: Value.ID) throws -> Value?
    var publisher: ValuePublisher { get }
}

internal struct AnyStoreDataSource<Value: Identifiable>: StoreDataSource {
    private let valueFor: (Value.ID) throws -> Value?
    let publisher: AnyPublisher<(Value.ID, Value?), Never>
    
    init<DS: StoreDataSource>(_ source: DS) where DS.Value == Value {
        self.valueFor = { id in try source.value(for: id) }
        self.publisher = source.publisher.eraseToAnyPublisher()
    }
    
    func value(for id: Value.ID) throws -> Value? {
        try valueFor(id)
    }
}
