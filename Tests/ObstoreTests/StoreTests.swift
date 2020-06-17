import XCTest
import Combine
import Obstore

final class StoreTests: XCTestCase {
    func testStrongReferences() {
        let dataSource: TestStoreDataSource<Foo> = .init([
            "a": Foo(id: "a", bar: 2),
            "b": Foo(id: "b", bar: 5),
        ])
        let store: Store<Foo> = .init(dataSource)

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
