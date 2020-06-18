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
            XCTAssertNil(try store.value(for: "a").value)
            
            dataSource.set(Foo(id: "a", bar: 2))
            
            let a = try store.value(for: "a")
            
            do {
                guard let aValue = a.value else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(aValue.id, "a")
                XCTAssertEqual(aValue.bar, 2)
            }
            
            let expectation1 = XCTestExpectation()
            let cancellable1 = a.objectWillChange
                .sink { foo in
                    guard let foo = foo else {
                        XCTFail()
                        return
                    }
                    XCTAssertEqual(foo.id, "a")
                    XCTAssertEqual(foo.bar, 3)
                    expectation1.fulfill()
                }

            dataSource.set(Foo(id: "a", bar: 3))
            
            wait(for: [expectation1], timeout: 2.0)
            cancellable1.cancel()

            do {
                guard let aValue = a.value else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(aValue.id, "a")
                XCTAssertEqual(aValue.bar, 3)
            }
            XCTAssertNil(try store.value(for: "b").value)
            
            dataSource.set(Foo(id: "b", bar: 5))
            
            let b = try store.value(for: "b")
            
            do {
                guard let bValue = b.value else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(bValue.id, "b")
                XCTAssertEqual(bValue.bar, 5)
            }

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

            do {
                guard let bValue = b.value else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(bValue.id, "b")
                XCTAssertEqual(bValue.bar, 7)
            }
            XCTAssertEqual(foos[1].id, "b")
            XCTAssertEqual(foos[1].bar, 7)
            
            let expectation3 = XCTestExpectation()
            let cancellable3 = foos.objectWillChange
                .sink { foos in
                    XCTAssertEqual(foos.count, 3)
                    XCTAssertEqual(foos[2].id, "c")
                    XCTAssertEqual(foos[2].bar, 11)
                    expectation3.fulfill()
                }
            
            dataSource.set(Foo(id: "c", bar: 11))
            
            wait(for: [expectation3], timeout: 2.0)
            cancellable3.cancel()

            XCTAssertEqual(foos.count, 3)
            XCTAssertEqual(foos[0].id, "a")
            XCTAssertEqual(foos[0].bar, 3)
            XCTAssertEqual(foos[1].id, "b")
            XCTAssertEqual(foos[1].bar, 7)
            XCTAssertEqual(foos[2].id, "c")
            XCTAssertEqual(foos[2].bar, 11)
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
    private let subject: PassthroughSubject<(Value.ID, Value?), Never> = .init()
    
    init(_ data: [Value.ID: Value] = [:]) {
        self.data = data
        self.publisher = subject.eraseToAnyPublisher()
    }
    
    func value(for id: Value.ID) throws -> Value? {
        data[id]
    }
    
    let publisher: AnyPublisher<(Value.ID, Value?), Never>
    
    func set(_ value: Value) {
        data[value.id] = value
        subject.send((value.id, value))
    }
    
    func removeValue(for id: Value.ID) {
        data.removeValue(forKey: id)
    }
}
