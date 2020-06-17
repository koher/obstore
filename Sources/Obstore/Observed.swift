import Combine
import Dispatch

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@dynamicMemberLookup
public class Observed<Value>: ObservableObject {
    internal init() {}
    
    public var value: Value {
        fatalError("Abstract")
    }
    
    public var objectWillChange: AnyPublisher<Value, Never> {
        fatalError("Abstract")
    }
    
    public subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
        value[keyPath: keyPath]
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
internal class CurrentValueObserved<Value>: Observed<Value> {
    private let subject: CurrentValueSubject<Value, Never>
    private let publisher: AnyPublisher<Value, Never>
    
    init(_ subject: CurrentValueSubject<Value, Never>) {
        self.subject = subject
        self.publisher = subject
            .receive(on: DispatchQueue.main)
            .dropFirst()
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
internal final class CombinedObserved<Value>: CurrentValueObserved<[Value]> {
    private let cancellables: [AnyCancellable]

    init(_ observedValues: [Observed<Value>]) {
        let currentValue: [Value] = observedValues.map { $0.value }
        
        let subject: CurrentValueSubject<[Value], Never> = .init(currentValue)
        var cancellables: [AnyCancellable] = []
        
        for (i, observedValue) in observedValues.enumerated() {
            observedValue.objectWillChange
                .sink { value in
                    subject.value[i] = value
                }
                .store(in: &cancellables)
        }
        
        self.cancellables = cancellables
        
        super.init(subject)
    }
}
