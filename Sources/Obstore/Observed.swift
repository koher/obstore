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
    private let observedValues: [Observed<Value?>] // to keep references
    private var cancellables: [AnyCancellable]

    init(_ observedValues: [Observed<Value?>]) {
        self.observedValues = observedValues
        cancellables = []

        let currentValues: [Value] = observedValues.compactMap { $0.value }
        let subject: CurrentValueSubject<[Value], Never> = .init(currentValues)

        super.init(subject)
        
        for observedValue in observedValues {
            observedValue.objectWillChange
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    let values: [Value] = self.observedValues.compactMap { $0.value }
                    subject.value = values
                }
                .store(in: &cancellables)
        }
    }
}
