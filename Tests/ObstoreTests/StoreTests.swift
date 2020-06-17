import XCTest
import Combine
import Obstore

final class StoreTests: XCTestCase {
    func testStrongReferences() {
        var cancellables: [AnyCancellable] = []
        
        var database: [String: Foo] = [
            "a": Foo(id: "a", bar: 2),
            "b": Foo(id: "b", bar: 5),
        ]
        let subject: PassthroughSubject<Foo, Never> = .init()
        subject.sink { foo in database[foo.id] = foo }.store(in: &cancellables)
        let store: Store<Foo> = .init(get : { id in database[id] }, update: subject.eraseToAnyPublisher())

        do {
            do {
                guard let a1 = try store.value(for: "a") else {
                    XCTFail()
                    return
                }
                guard let a2 = try store.value(for: "a") else {
                    XCTFail()
                    return
                }
                XCTAssertTrue(a1 === a2)
            }
            
            do {
                weak var a1: Observed<Foo>?
                do {
                    let a2 = try store.value(for: "a")
                    a1 = try store.value(for: "a")
                    XCTAssertTrue(a1! === a2)
                }
                XCTAssertNil(a1)
            }
            
            do {
                weak var a: Observed<Foo>?
                do {
                    try withExtendedLifetime(try store.values(for: ["b", "a"])) { _ in
                        a = try store.value(for: "a")
                        XCTAssertNotNil(a)
                    }
                }
                XCTAssertNil(a)
            }
        } catch {
            XCTFail("\(error)")
        }
    }
}
