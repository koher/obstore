import XCTest
import Combine
import Obstore

final class ObstoreTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
    }
    
    func testBasics() {
        let dataSource: TestStoreDataSource<Foo> = .init()
        let store: Store<Foo> = .init(dataSource)
        
        do {
            XCTAssertNil(try store.value(for: "a"))
            
            dataSource.set(Foo(id: "a", bar: 2))
            
            guard let a = try store.value(for: "a") else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(a.id, "a")
            XCTAssertEqual(a.bar, 2)
            
            let expectation1 = XCTestExpectation()
            let cancellable1 = a.objectWillChange
                .sink { foo in
                    XCTAssertEqual(foo.id, "a")
                    XCTAssertEqual(foo.bar, 3)
                    expectation1.fulfill()
                }

            dataSource.set(Foo(id: "a", bar: 3))
            
            wait(for: [expectation1], timeout: 2.0)
            cancellable1.cancel()

            XCTAssertEqual(a.id, "a")
            XCTAssertEqual(a.bar, 3)
            XCTAssertNil(try store.value(for: "b"))
            
            guard let a2 = try store.value(for: "a") else {
                XCTFail()
                return
            }
            XCTAssertTrue(a === a2)

            dataSource.set(Foo(id: "b", bar: 5))
            
            guard let b = try store.value(for: "b") else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(b.id, "b")
            XCTAssertEqual(b.bar, 5)

            let foos = try store.values(for: ["a", "b", "c"])
            
            XCTAssertEqual(foos.count, 2)
            XCTAssertEqual(foos[0].id, "a")
            XCTAssertEqual(foos[0].bar, 3)
            XCTAssertEqual(foos[1].id, "b")
            XCTAssertEqual(foos[1].bar, 5)
            
            let expectation2 = XCTestExpectation()
            let cancellable2 = foos.objectWillChange
                .sink { foos in
                    XCTAssertEqual(foos[1].id, "b")
                    XCTAssertEqual(foos[1].bar, 7)
                    expectation2.fulfill()
                }

            dataSource.set(Foo(id: "b", bar: 7))

            wait(for: [expectation2], timeout: 2.0)
            cancellable2.cancel()
            
            XCTAssertEqual(b.id, "b")
            XCTAssertEqual(b.bar, 7)
            XCTAssertEqual(foos[1].id, "b")
            XCTAssertEqual(foos[1].bar, 7)
        } catch {
            XCTFail("\(error)")
        }
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

struct Foo: Identifiable {
    let id: String
    var bar: Int
}

final class TestStoreDataSource<Value: Identifiable>: StoreDataSource {
    private var data: [Value.ID: Value]
    private let subject: PassthroughSubject<Value, Never> = .init()
    
    init(_ data: [Value.ID: Value] = [:]) {
        self.data = data
        self.publisher = subject.eraseToAnyPublisher()
    }
    
    func value(for id: Value.ID) throws -> Value? {
        data[id]
    }
    
    let publisher: AnyPublisher<Value, Never>
    
    func set(_ value: Value) {
        data[value.id] = value
        subject.send(value)
    }
}
