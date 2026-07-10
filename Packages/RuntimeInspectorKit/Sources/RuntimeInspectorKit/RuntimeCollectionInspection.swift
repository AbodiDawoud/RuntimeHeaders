import Foundation

public final class InspectableCollectionReference: Identifiable {
    public let id: String
    public let kind: String
    public let displayName: String
    public let acquisitionDescription: String
    public let totalCount: Int
    public let entries: [InspectableCollectionEntry]
    public let isTruncated: Bool
    public let objectReference: InspectableObjectReference

    public init?(
        object: AnyObject,
        acquisitionDescription: String,
        maxEntries: Int = 200,
        depth: Int = 0,
        maxDepth: Int = 2
    ) {
        guard let snapshot = RuntimeCollectionSnapshot(
            object: object,
            acquisitionDescription: acquisitionDescription,
            maxEntries: maxEntries,
            depth: depth,
            maxDepth: maxDepth
        ) else { return nil }

        let objectReference = InspectableObjectReference(
            object: object,
            acquisitionDescription: acquisitionDescription
        )

        self.id = "\(objectReference.id):collection"
        self.kind = snapshot.kind
        self.displayName = "\(snapshot.kind) (\(snapshot.totalCount))"
        self.acquisitionDescription = acquisitionDescription
        self.totalCount = snapshot.totalCount
        self.entries = snapshot.entries
        self.isTruncated = snapshot.isTruncated
        self.objectReference = objectReference
    }
}

public struct InspectableCollectionEntry: Identifiable {
    public let id: String
    public let title: String
    public let values: [InspectableCollectionValue]

    public init(id: String, title: String, values: [InspectableCollectionValue]) {
        self.id = id
        self.title = title
        self.values = values
    }
}

public struct InspectableCollectionValue: Identifiable {
    public let id: String
    public let role: String
    public let valueDescription: String
    public let objectReference: InspectableObjectReference?
    public let collectionReference: InspectableCollectionReference?

    public init(
        id: String,
        role: String,
        valueDescription: String,
        objectReference: InspectableObjectReference?,
        collectionReference: InspectableCollectionReference?
    ) {
        self.id = id
        self.role = role
        self.valueDescription = valueDescription
        self.objectReference = objectReference
        self.collectionReference = collectionReference
    }

    public var isDrillable: Bool {
        collectionReference != nil || objectReference != nil
    }
}

private struct RuntimeCollectionSnapshot {
    let kind: String
    let totalCount: Int
    let entries: [InspectableCollectionEntry]
    let isTruncated: Bool

    private init(
        kind: String,
        totalCount: Int,
        entries: [InspectableCollectionEntry],
        isTruncated: Bool
    ) {
        self.kind = kind
        self.totalCount = totalCount
        self.entries = entries
        self.isTruncated = isTruncated
    }

    init?(
        object: AnyObject,
        acquisitionDescription: String,
        maxEntries: Int,
        depth: Int,
        maxDepth: Int
    ) {
        if let dictionary = object as? NSDictionary {
            self = Self.dictionary(
                dictionary,
                acquisitionDescription: acquisitionDescription,
                maxEntries: maxEntries,
                depth: depth,
                maxDepth: maxDepth
            )
            return
        }

        if let array = object as? NSArray {
            self = Self.indexed(
                kind: "Array",
                values: (0..<array.count).map { array.object(at: $0) },
                acquisitionDescription: acquisitionDescription,
                maxEntries: maxEntries,
                depth: depth,
                maxDepth: maxDepth
            )
            return
        }

        if let orderedSet = object as? NSOrderedSet {
            self = Self.indexed(
                kind: "Ordered Set",
                values: (0..<orderedSet.count).map { orderedSet.object(at: $0) },
                acquisitionDescription: acquisitionDescription,
                maxEntries: maxEntries,
                depth: depth,
                maxDepth: maxDepth
            )
            return
        }

        if let set = object as? NSSet {
            self = Self.indexed(
                kind: "Set",
                values: set.allObjects.sorted(by: Self.valueSort),
                acquisitionDescription: acquisitionDescription,
                maxEntries: maxEntries,
                depth: depth,
                maxDepth: maxDepth
            )
            return
        }

        if let hashTable = object as? NSHashTable<AnyObject> {
            self = Self.indexed(
                kind: "Hash Table",
                values: hashTable.allObjects.sorted(by: Self.valueSort),
                acquisitionDescription: acquisitionDescription,
                maxEntries: maxEntries,
                depth: depth,
                maxDepth: maxDepth
            )
            return
        }

        if let mapTable = object as? NSMapTable<AnyObject, AnyObject> {
            self = Self.mapTable(
                mapTable,
                acquisitionDescription: acquisitionDescription,
                maxEntries: maxEntries,
                depth: depth,
                maxDepth: maxDepth
            )
            return
        }

        return nil
    }

    private static func indexed(
        kind: String,
        values: [Any],
        acquisitionDescription: String,
        maxEntries: Int,
        depth: Int,
        maxDepth: Int
    ) -> RuntimeCollectionSnapshot {
        let entries = values.prefix(maxEntries).enumerated().map { offset, value in
            InspectableCollectionEntry(
                id: "\(offset)",
                title: "[\(offset)]",
                values: [
                    collectionValue(
                        id: "item:\(offset)",
                        role: "Item",
                        value: value,
                        acquisitionDescription: "\(acquisitionDescription)[\(offset)]",
                        depth: depth,
                        maxDepth: maxDepth
                    )
                ]
            )
        }

        return RuntimeCollectionSnapshot(
            kind: kind,
            totalCount: values.count,
            entries: entries,
            isTruncated: values.count > maxEntries
        )
    }

    private static func dictionary(
        _ dictionary: NSDictionary,
        acquisitionDescription: String,
        maxEntries: Int,
        depth: Int,
        maxDepth: Int
    ) -> RuntimeCollectionSnapshot {
        let keys = dictionary.allKeys.sorted(by: valueSort)
        let entries = keys.prefix(maxEntries).enumerated().map { offset, key in
            let value = dictionary.object(forKey: key) ?? NSNull()
            return InspectableCollectionEntry(
                id: "entry:\(offset)",
                title: "Entry \(offset + 1)",
                values: [
                    collectionValue(
                        id: "key:\(offset)",
                        role: "Key",
                        value: key,
                        acquisitionDescription: "\(acquisitionDescription).key[\(offset)]",
                        depth: depth,
                        maxDepth: maxDepth
                    ),
                    collectionValue(
                        id: "value:\(offset)",
                        role: "Value",
                        value: value,
                        acquisitionDescription: "\(acquisitionDescription)[\(RuntimeInvocationEngine.describe(value: key))]",
                        depth: depth,
                        maxDepth: maxDepth
                    )
                ]
            )
        }

        return RuntimeCollectionSnapshot(
            kind: "Dictionary",
            totalCount: dictionary.count,
            entries: entries,
            isTruncated: dictionary.count > maxEntries
        )
    }

    private static func mapTable(
        _ mapTable: NSMapTable<AnyObject, AnyObject>,
        acquisitionDescription: String,
        maxEntries: Int,
        depth: Int,
        maxDepth: Int
    ) -> RuntimeCollectionSnapshot {
        var pairs: [(key: AnyObject, value: AnyObject)] = []
        let keyEnumerator = mapTable.keyEnumerator()
        while let key = keyEnumerator.nextObject() as AnyObject? {
            guard let value = mapTable.object(forKey: key) else { continue }
            pairs.append((key, value))
        }

        pairs.sort { valueSort($0.key, $1.key) }

        let entries = pairs.prefix(maxEntries).enumerated().map { offset, pair in
            InspectableCollectionEntry(
                id: "entry:\(offset)",
                title: "Entry \(offset + 1)",
                values: [
                    collectionValue(
                        id: "key:\(offset)",
                        role: "Key",
                        value: pair.key,
                        acquisitionDescription: "\(acquisitionDescription).key[\(offset)]",
                        depth: depth,
                        maxDepth: maxDepth
                    ),
                    collectionValue(
                        id: "value:\(offset)",
                        role: "Value",
                        value: pair.value,
                        acquisitionDescription: "\(acquisitionDescription)[\(RuntimeInvocationEngine.describe(value: pair.key))]",
                        depth: depth,
                        maxDepth: maxDepth
                    )
                ]
            )
        }

        return RuntimeCollectionSnapshot(
            kind: "Map Table",
            totalCount: pairs.count,
            entries: entries,
            isTruncated: pairs.count > maxEntries
        )
    }

    private static func collectionValue(
        id: String,
        role: String,
        value: Any,
        acquisitionDescription: String,
        depth: Int,
        maxDepth: Int
    ) -> InspectableCollectionValue {
        let object = value as AnyObject
        let collectionReference: InspectableCollectionReference?
        if depth < maxDepth {
            collectionReference = InspectableCollectionReference(
                object: object,
                acquisitionDescription: acquisitionDescription,
                depth: depth + 1,
                maxDepth: maxDepth
            )
        } else {
            collectionReference = nil
        }
        let objectReference: InspectableObjectReference?
        if collectionReference == nil, shouldExposeObjectReference(object) {
            objectReference = InspectableObjectReference(
                object: object,
                acquisitionDescription: acquisitionDescription
            )
        } else {
            objectReference = nil
        }

        return InspectableCollectionValue(
            id: id,
            role: role,
            valueDescription: RuntimeInvocationEngine.describe(value: value),
            objectReference: objectReference,
            collectionReference: collectionReference
        )
    }

    private static func valueSort(_ lhs: Any, _ rhs: Any) -> Bool {
        RuntimeInvocationEngine.describe(value: lhs)
            .localizedCaseInsensitiveCompare(RuntimeInvocationEngine.describe(value: rhs)) == .orderedAscending
    }

    private static func shouldExposeObjectReference(_ object: AnyObject) -> Bool {
        switch object {
        case is NSString, is NSNumber, is NSNull, is NSDate, is NSData, is NSURL:
            return false
        default:
            return true
        }
    }
}
