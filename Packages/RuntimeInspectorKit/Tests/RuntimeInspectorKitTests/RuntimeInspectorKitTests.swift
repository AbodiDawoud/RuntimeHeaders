import Combine
import ObjectiveC.runtime
import XCTest
@testable import RuntimeInspectorKit

@MainActor
final class RuntimeInspectorKitTests: XCTestCase {
    func testScalarReturnsPreserveTheirWidths() throws {
        let fixture = InvocationFixture()
        for (selector, expected) in [
            ("signed16", "-7"), ("signed32", "-7"), ("signed64", "-7"),
            ("unsigned16", "65535"), ("unsigned32", "4294967295"),
            ("unsigned64", "18446744073709551615"),
            ("floatValue", "1.25"), ("doubleValue", "2.5"), ("boolValue", "false")
        ] {
            XCTAssertEqual(try invoke(selector, on: fixture).valueDescription, expected, selector)
        }
    }

    func testMixedArgumentsUseTheDeclaredTypes() throws {
        let fixture = InvocationFixture()
        let result = try invoke("combine:count:scale:", on: fixture,
                                arguments: [.string("test"), .integer(-2), .double(0.5)])
        XCTAssertEqual(Double(result.valueDescription), 3)
        XCTAssertEqual(fixture.calls, 1)
    }

    func testLegacyLongEncodingUses32Bits() throws {
        let source = try XCTUnwrap(class_getInstanceMethod(InvocationFixture.self, NSSelectorFromString("signed32")))
        XCTAssertTrue(class_addMethod(InvocationFixture.self, NSSelectorFromString("legacyLong"),
                                      method_getImplementation(source), "l@:"))
        XCTAssertEqual(try invoke("legacyLong", on: InvocationFixture()).valueDescription, "-7")
    }

    func testInvalidArgumentsAreRejectedBeforeCallingTheReceiver() {
        let fixture = InvocationFixture()
        for value in [Int(Int16.min) - 1, Int(Int16.max) + 1] {
            XCTAssertThrowsError(try invoke("echoSigned:", on: fixture, arguments: [.integer(value)]))
        }
        XCTAssertThrowsError(try invoke("echoUnsigned:", on: fixture,
                                       arguments: [.unsignedInteger(UInt(UInt32.max) + 1)]))
        XCTAssertThrowsError(try invoke("echoSigned:", on: fixture, arguments: [.string("7")]))
        XCTAssertThrowsError(try invoke("echoSigned:", on: fixture))
        XCTAssertEqual(fixture.calls, 0)
    }

    func testIntegerArgumentBoundariesAreAccepted() throws {
        let fixture = InvocationFixture()
        for value in [Int(Int16.min), Int(Int16.max)] {
            XCTAssertEqual(try invoke("echoSigned:", on: fixture, arguments: [.integer(value)]).valueDescription,
                           String(value))
        }
        XCTAssertEqual(try invoke("echoUnsigned:", on: fixture,
                                  arguments: [.unsignedInteger(UInt(UInt32.max))]).valueDescription,
                       String(UInt32.max))
    }

    func testNilAndVoidAreSuccessfulResults() throws {
        let fixture = InvocationFixture()
        let result = try invoke("nilValue", on: fixture)
        XCTAssertEqual(result.valueDescription, "nil")
        XCTAssertNil(result.object)
        XCTAssertEqual(try invoke("finish", on: fixture).valueDescription, "Completed")
    }

    func testChangedReturnSignatureIsRejected() {
        XCTAssertThrowsError(try RuntimeInvocationEngine.invokeInstanceMethod(
            on: InvocationFixture(), selector: NSSelectorFromString("signed32"), returnTypeEncoding: "d"
        ))
    }

    func testObjectiveCExceptionBecomesAnError() throws {
        weak var receiver: NSMutableArray?
        try autoreleasepool {
            let array = NSMutableArray()
            receiver = array
            XCTAssertThrowsError(try invoke("objectAtIndex:", on: array, arguments: [.unsignedInteger(0)])) { error in
                XCTAssertTrue(error.localizedDescription.contains("NSRangeException"))
            }
        }
        XCTAssertNil(receiver)
    }

    func testCreatedInstanceIsReleased() {
        weak var object: AnyObject?
        autoreleasepool {
            let resolved = RuntimeInspector.createZeroArgumentInstance(classNamed: NSStringFromClass(InvocationFixture.self))
            XCTAssertNotNil(resolved)
            object = resolved?.object
            XCTAssertNotNil(object)
        }
        XCTAssertNil(object)
    }

    func testOwnedFactoryResultIsReleased() throws {
        weak var object: AnyObject?
        try autoreleasepool {
            object = try RuntimeInvocationEngine.invokeClassObjectMethod(
                on: InvocationFixture.self, selector: NSSelectorFromString("newObject")
            )
        }
        XCTAssertNil(object)
    }

    func testClassScalarMethod() throws {
        let result = try RuntimeInvocationEngine.invokeClassMethod(
            on: InvocationFixture.self, selector: NSSelectorFromString("classValue"), returnTypeEncoding: "i"
        )
        XCTAssertEqual(result.valueDescription, "-7")
    }

    func testCompletedCallbackOnlyUpdatesOnce() async throws {
        let fixture = InvocationFixture()
        let model = inspector(for: fixture)
        let method = try XCTUnwrap(model.methods.first { $0.selectorName == "waitForResult:" })
        model.invoke(method, arguments: [model.completionHandlerArgument(for: method, signature: .void)])
        let completed = expectation(description: "Completion is displayed")
        let subscription = model.$lastInvocation.sink { result in
            if result?.valueDescription.hasPrefix("Completion handler fired") == true { completed.fulfill() }
        }
        fixture.completion?()
        await fulfillment(of: [completed], timeout: 1)
        subscription.cancel()
        await assertNoResultUpdate(model) { fixture.completion?() }
    }

    func testOldCallbackCannotReplaceANewerResult() async throws {
        let fixture = InvocationFixture()
        let model = inspector(for: fixture)
        let method = try XCTUnwrap(model.methods.first { $0.selectorName == "waitForResult:" })
        model.invoke(method, arguments: [model.completionHandlerArgument(for: method, signature: .void)])
        let newer = try XCTUnwrap(model.methods.first { $0.selectorName == "signed32" })
        model.invoke(newer)
        await assertNoResultUpdate(model) { fixture.completion?() }
        XCTAssertEqual(model.lastInvocation?.selectorName, "signed32")
    }

    func testDismissedResultStaysDismissed() async throws {
        let fixture = InvocationFixture()
        let model = inspector(for: fixture)
        let method = try XCTUnwrap(model.methods.first { $0.selectorName == "waitForResult:" })
        model.invoke(method, arguments: [model.completionHandlerArgument(for: method, signature: .void)])
        model.clearLastInvocationResult()
        await assertNoResultUpdate(model) { fixture.completion?() }
        XCTAssertNil(model.lastInvocation)
    }

    func testCollectionDescriptionDoesNotExpandItsContents() {
        XCTAssertEqual(RuntimeInvocationEngine.describe(value: NSArray(array: Array(0..<1000))), "[1000 items]")
        XCTAssertEqual(RuntimeInvocationEngine.describe(value: NSDictionary(dictionary: ["key": "value"])), "[1 pairs]")
    }

    func testNestedCollectionsRespectTheEntryLimit() throws {
        let collection = NSArray(array: [NSArray(array: Array(0..<10))])
        let snapshot = try XCTUnwrap(InspectableCollectionReference(
            object: collection, acquisitionDescription: "fixture", maxEntries: 1
        ))
        let nested = try XCTUnwrap(snapshot.entries.first?.values.first?.collectionReference)
        XCTAssertEqual(nested.entries.count, 1)
        XCTAssertEqual(nested.totalCount, 10)
        XCTAssertTrue(nested.isTruncated)
        XCTAssertTrue(try XCTUnwrap(InspectableCollectionReference(
            object: collection, acquisitionDescription: "fixture", maxEntries: -1
        )).entries.isEmpty)
    }

    private func invoke(_ name: String, on object: AnyObject,
                        arguments: [RuntimeInvocationArgument] = []) throws -> RuntimeInvocationOutput {
        let selector = NSSelectorFromString(name)
        let method = try XCTUnwrap(class_getInstanceMethod(object_getClass(object), selector))
        return try RuntimeInvocationEngine.invokeInstanceMethod(
            on: object, selector: selector,
            returnTypeEncoding: RuntimeInvocationEngine.methodReturnType(method), arguments: arguments
        )
    }

    private func inspector(for object: InvocationFixture) -> RuntimeObjectInspectorViewModel {
        RuntimeObjectInspectorViewModel(resolvedInstance: ResolvedRuntimeInstance(
            className: NSStringFromClass(InvocationFixture.self), selectorName: "fixture",
            acquisitionDescription: "Test fixture", subjectKind: .instance,
            targetClass: InvocationFixture.self, object: object
        ))
    }

    private func assertNoResultUpdate(_ model: RuntimeObjectInspectorViewModel, action: () -> Void) async {
        let unchanged = expectation(description: "No stale result publication")
        unchanged.isInverted = true
        let subscription = model.$lastInvocation.dropFirst().sink { _ in unchanged.fulfill() }
        action()
        await fulfillment(of: [unchanged], timeout: 0.05)
        subscription.cancel()
    }
}

@objc(RIInvocationTestFixture)
private final class InvocationFixture: NSObject {
    var calls = 0
    var completion: (@convention(block) () -> Void)?

    @objc dynamic func signed16() -> Int16 { -7 }
    @objc dynamic func signed32() -> Int32 { -7 }
    @objc dynamic func signed64() -> Int64 { -7 }
    @objc dynamic func unsigned16() -> UInt16 { .max }
    @objc dynamic func unsigned32() -> UInt32 { .max }
    @objc dynamic func unsigned64() -> UInt64 { .max }
    @objc dynamic func floatValue() -> Float { 1.25 }
    @objc dynamic func doubleValue() -> Double { 2.5 }
    @objc dynamic func boolValue() -> Bool { false }
    @objc dynamic func nilValue() -> AnyObject? { nil }
    @objc dynamic func finish() { calls += 1 }
    @objc dynamic class func newObject() -> NSObject { NSObject() }
    @objc dynamic class func classValue() -> Int32 { -7 }
    @objc dynamic func echoSigned(_ value: Int16) -> Int16 { calls += 1; return value }
    @objc dynamic func echoUnsigned(_ value: UInt32) -> UInt32 { calls += 1; return value }
    @objc dynamic func combine(_ text: String, count: Int16, scale: Double) -> Double {
        calls += 1
        return Double(text.count) + Double(count) * scale
    }
    @objc dynamic func waitForResult(_ callback: @escaping @convention(block) () -> Void) {
        completion = callback
    }
}
