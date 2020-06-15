import Combine
import Dispatch

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class Observed<Value>: ObservableObject {
    internal init() {}
    
    public var value: Value {
        fatalError("Abstract")
    }
    
    public var objectWillChange: AnyPublisher<Value, Never> {
        fatalError("Abstract")
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
internal final class CurrentValueObserved<Value>: Observed<Value> {
    private let subject: CurrentValueSubject<Value, Never>
    private let publisher: AnyPublisher<Value, Never>
    
    init(_ subject: CurrentValueSubject<Value, Never>) {
        self.subject = subject
        self.publisher = subject
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
        
        super.init()
    }
    
    override var value: Value {
        get { subject.value }
        set { subject.value = newValue }
    }
    
    override var objectWillChange: AnyPublisher<Value, Never> {
        publisher
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
internal final class AnyObserved<Value>: Observed<Value> {
    private let publisher: AnyPublisher<Value, Never>
    
    private var currentValue: Value
    private var cancellable: AnyCancellable? = nil

    init(_ value: Value, publisher: AnyPublisher<Value, Never>) {
        self.currentValue = value
        self.publisher = publisher
        
        super.init()
        
        cancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.currentValue = value
            }
    }
    
    override var value: Value { currentValue }
    override var objectWillChange: AnyPublisher<Value, Never> { publisher }
}
