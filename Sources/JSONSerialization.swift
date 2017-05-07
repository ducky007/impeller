//
//  JSONRepository.swift
//  Impeller
//
//  Created by Drew McCormack on 26/01/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation


public enum JSONSerializationError: Error {
    case invalidMetadata
    case invalidFormat(reason: String)
    case invalidProperty(reason: String)
    case invalidMonolithicRepository(reason: String)
    case invalidForest(reason: String)
    case invalidHistory(reason: String)
    case invalidCommit(reason: String)
}


protocol JSONRepresentable {
    init(withJSONRepresentation json: Any) throws
    func JSONRepresentation() -> Any
}


extension MonolithicRepository {
    
    private enum JSONKey: String {
        case history, forest, uniqueIdentifier
    }
    
    public convenience init(withJSONAt url:URL) throws {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
            throw JSONSerializationError.invalidFormat(reason: "JSON root was not a dictionary")
        }
        try self.init(withJSONRepresentation: json)
    }
    
    public convenience init(withJSONRepresentation json: Any) throws {
        self.init()
        
        guard
            let json = json as? [String:Any],
            let forestData = json[JSONKey.forest.rawValue],
            let historyData = json[JSONKey.history.rawValue],
            let uniqueIdentifier = json[JSONKey.uniqueIdentifier.rawValue] as? UniqueIdentifier else {
            throw JSONSerializationError.invalidMonolithicRepository(reason: "No valid repo found")
        }
        
        self.uniqueIdentifier = uniqueIdentifier
        self.forest = try Forest(withJSONRepresentation: forestData)
        self.history = try History(withJSONRepresentation: historyData)
    }
    
    public func saveJSON(to url:URL) throws {
        let data = try JSONSerialization.data(withJSONObject: JSONRepresentation(), options: [])
        try data.write(to: url)
    }
    
    public func JSONRepresentation() -> Any {
        var json = [String:Any]()
        json[JSONKey.history.rawValue] = history.JSONRepresentation()
        json[JSONKey.forest.rawValue] = forest.JSONRepresentation()
        json[JSONKey.uniqueIdentifier.rawValue] = uniqueIdentifier
        return json
    }
    
}


extension Forest: JSONRepresentable {
    private enum JSONKey: String {
        case valueTrees
    }
    
    public init(withJSONRepresentation json: Any) throws {
        guard
            let json = json as? [String:Any],
            let valueTreeDicts = json[JSONKey.valueTrees.rawValue] as? [String:Any] else {
            throw JSONSerializationError.invalidForest(reason: "No value trees found")
        }
        
        let trees = try valueTreeDicts.map { (_, json) in try ValueTree(withJSONRepresentation: json) }
        self.init(valueTrees: trees)
    }
    
    public func JSONRepresentation() -> Any {
        var treesDict = [String:Any]()
        for tree in self {
            let key = tree.valueTreeReference.asString
            treesDict[key] = tree.JSONRepresentation()
        }
        return [JSONKey.valueTrees.rawValue: treesDict]
    }
}


extension ValueTree: JSONRepresentable {
    
    private enum JSONKey: String {
        case metadata, repositedType, uniqueIdentifier, commitIdentifier, isDeleted, propertiesByName, timestampsByPropertyName, ancestry, commits
    }
    
    public init(withJSONRepresentation json: Any) throws {
        guard let json = json as? [String:Any] else {
            throw JSONSerializationError.invalidFormat(reason: "No root dictionary in JSON")
        }
        
        guard
            let metadataDict = json[JSONKey.metadata.rawValue] as? [String:Any],
            let id = metadataDict[JSONKey.uniqueIdentifier.rawValue] as? String,
            let repositedType = metadataDict[JSONKey.repositedType.rawValue] as? RepositedType,
            let commitIdentifier = metadataDict[JSONKey.commitIdentifier.rawValue] as? CommitIdentifier,
            let timestampsByPropertyName = metadataDict[JSONKey.timestampsByPropertyName.rawValue] as? [String:TimeInterval],
            let isDeleted = metadataDict[JSONKey.isDeleted.rawValue] as? Bool,
            let ancestry = metadataDict[JSONKey.ancestry.rawValue] as? [[String:String]] else {
            throw JSONSerializationError.invalidMetadata
        }
        
        var metadata = Metadata(uniqueIdentifier: id)
        metadata.commitIdentifier = commitIdentifier
        metadata.isDeleted = isDeleted
        metadata.timestampsByPropertyName = timestampsByPropertyName
        metadata.ancestry = ancestry.map {
            let uniqueId = $0[JSONKey.uniqueIdentifier.rawValue]!
            let type = $0[JSONKey.repositedType.rawValue]!
            return ValueTreeIdentity(uniqueIdentifier: uniqueId, repositedType: type)
        }
        
        self.repositedType = repositedType
        self.metadata = metadata
        
        guard let propertiesByName = json[JSONKey.propertiesByName.rawValue] as? [String:Any] else {
            throw JSONSerializationError.invalidFormat(reason: "No properties dictionary found for object")
        }
        self.propertiesByName = try propertiesByName.mapValues {
            try Property(withJSONRepresentation: $1 as AnyObject)
        }
    }
    
    public func JSONRepresentation() -> Any {
        var json = [String:Any]()
        let metadataDict: [String:Any] = [
            JSONKey.repositedType.rawValue : repositedType,
            JSONKey.uniqueIdentifier.rawValue : metadata.uniqueIdentifier,
            JSONKey.commitIdentifier.rawValue : metadata.commitIdentifier!,
            JSONKey.isDeleted.rawValue : metadata.isDeleted,
            JSONKey.timestampsByPropertyName.rawValue : metadata.timestampsByPropertyName,
            JSONKey.ancestry.rawValue : metadata.ancestry!.map {
                [JSONKey.repositedType.rawValue: $0.repositedType, JSONKey.uniqueIdentifier.rawValue: $0.uniqueIdentifier]
            }
        ]
        json[JSONKey.metadata.rawValue] = metadataDict
        json[JSONKey.propertiesByName.rawValue] = propertiesByName.mapValues { _, property in
            return property.JSONRepresentation()
        }
        return json
    }
    
}


extension Property: JSONRepresentable {
    
    private enum JSONKey: String {
        case propertyType, primitiveType, value, referencedType, referencedIdentifier, referencedIdentifiers, referencedCommits, referencedCommitIdentifier
    }
    
    public init(withJSONRepresentation json: Any) throws {
        guard
            let json = json as? [String:Any],
            let propertyTypeInt = json[JSONKey.propertyType.rawValue] as? Int,
            let propertyType = PropertyType(rawValue: propertyTypeInt) else {
            throw JSONSerializationError.invalidProperty(reason: "No valid property type")
        }

        let primitiveTypeInt = json[JSONKey.primitiveType.rawValue] as? Int
        let primitiveType = primitiveTypeInt != nil ? PrimitiveType(rawValue: primitiveTypeInt!) : nil

        switch propertyType {
        case .primitive:
            guard
                let primitiveType = primitiveType,
                let value = json[JSONKey.value.rawValue] else {
                throw JSONSerializationError.invalidProperty(reason: "No primitive type or value found")
            }
            self = try Property(withPrimitiveType: primitiveType, value: value)
        case .optionalPrimitive:
            let isNull = primitiveTypeInt == 0
            if isNull {
                self = .optionalPrimitive(nil)
            }
            else {
                guard
                    let primitiveType = primitiveType,
                    let value = json[JSONKey.value.rawValue] else {
                    throw JSONSerializationError.invalidProperty(reason: "No primitive type or value found")
                }
                self = try Property(withPrimitiveType: primitiveType, value: value)
            }
        case .primitives:
            let isEmpty = primitiveTypeInt == 0
            if isEmpty {
                self = .primitives([])
            }
            else {
                guard
                    let primitiveType = primitiveType,
                    let value = json[JSONKey.value.rawValue] as? [Any] else {
                    throw JSONSerializationError.invalidProperty(reason: "No primitive type or value found")
                }
                switch primitiveType {
                case .string:
                    guard let v = value as? [String] else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
                    self = .primitives(v.map { .string($0) })
                case .int:
                    guard let v = value as? [Int] else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
                    self = .primitives(v.map { .int($0) })
                case .float:
                    guard let v = value as? [Float] else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
                    self = .primitives(v.map { .float($0) })
                case .bool:
                    guard let v = value as? [Bool] else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
                    self = .primitives(v.map { .bool($0) })
                case .data:
                    guard let v = value as? [Data] else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
                    self = .primitives(v.map { .data($0) })
                }
            }
        case .valueTreeReference:
            self = try Property(withReferenceDictionary: json)
        case .optionalValueTreeReference:
            if let referencedType = json[JSONKey.referencedType.rawValue] as? Int, referencedType == 0 {
                self = .optionalValueTreeReference(nil)
            }
            else {
                self = try Property(withReferenceDictionary: json)
            }
        case .valueTreeReferences:
            if let referencedType = json[JSONKey.referencedType.rawValue] as? Int, referencedType == 0 {
                self = .valueTreeReferences([])
            }
            else {
                guard
                    let referencedType = json[JSONKey.referencedType.rawValue] as? String,
                    let referencedIdentifiers = json[JSONKey.referencedIdentifiers.rawValue] as? [String],
                    let referencedCommitIdentifiers = json[JSONKey.referencedCommits.rawValue] as? [String] else {
                    throw JSONSerializationError.invalidProperty(reason: "No primitive type or value found")
                }
                let idCommitTuples = zip(referencedIdentifiers, referencedCommitIdentifiers)
                let refs = idCommitTuples.map { ValueTreeReference(uniqueIdentifier: $0.0, repositedType: referencedType, commitIdentifier: $0.1) }
                self = .valueTreeReferences(refs)
            }
        }
    }
    
    private init(withPrimitiveType primitiveType: PrimitiveType, value: Any) throws {
        switch primitiveType {
        case .string:
            guard let v = value as? String else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
            self = .primitive(.string(v))
        case .int:
            guard let v = value as? Int else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
            self = .primitive(.int(v))
        case .float:
            guard let v = value as? Float else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
            self = .primitive(.float(v))
        case .bool:
            guard let v = value as? Bool else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
            self = .primitive(.bool(v))
        case .data:
            guard let v = value as? Data else { throw JSONSerializationError.invalidProperty(reason: "Wrong type found") }
            self = .primitive(.data(v))
        }
    }
    
    private init(withReferenceDictionary dict: [String:Any]) throws {
        guard
            let referencedType = dict[JSONKey.referencedType.rawValue] as? String,
            let referencedIdentifier = dict[JSONKey.referencedIdentifier.rawValue] as? String else {
                throw JSONSerializationError.invalidProperty(reason: "No primitive type or value found")
        }
        let commitIdentifier = dict[JSONKey.referencedCommitIdentifier.rawValue] as? String
        let ref = ValueTreeReference(uniqueIdentifier: referencedIdentifier, repositedType: referencedType, commitIdentifier: commitIdentifier)
        self = .valueTreeReference(ref)
    }
    
    public func JSONRepresentation() -> Any {
        var result = [String:Any]()
        result[JSONKey.propertyType.rawValue] = propertyType.rawValue
        
        switch self {
        case .primitive(let primitive):
            result[JSONKey.primitiveType.rawValue] = primitive.type.rawValue
            result[JSONKey.value.rawValue] = primitive.value
        case .optionalPrimitive(let primitive):
            if let primitive = primitive {
                result[JSONKey.primitiveType.rawValue] = primitive.type.rawValue
                result[JSONKey.value.rawValue] = primitive.value
            }
            else {
                result[JSONKey.primitiveType.rawValue] = 0
            }
        case .primitives(let primitives):
            if primitives.count > 0 {
                result[JSONKey.primitiveType.rawValue] = primitives.first!.type.rawValue
                result[JSONKey.value.rawValue] = primitives.map { $0.value }
            }
            else {
                result[JSONKey.primitiveType.rawValue] = 0
            }
        case .valueTreeReference(let ref):
            result[JSONKey.referencedType.rawValue] = ref.identity.repositedType
            result[JSONKey.referencedIdentifier.rawValue] = ref.identity.uniqueIdentifier
        case .optionalValueTreeReference(let ref):
            if let ref = ref {
                result[JSONKey.referencedType.rawValue] = ref.identity.repositedType
                result[JSONKey.referencedIdentifier.rawValue] = ref.identity.uniqueIdentifier
            }
            else {
                result[JSONKey.referencedType.rawValue] = 0
            }
        case .valueTreeReferences(let refs):
            if refs.count > 0 {
                result[JSONKey.referencedType.rawValue] = refs.first!.identity.repositedType
                result[JSONKey.referencedIdentifiers.rawValue] = refs.map { $0.identity.uniqueIdentifier }
            }
            else {
                result[JSONKey.referencedType.rawValue] = 0
            }
        }
        
        return result as AnyObject
    }
    
}


extension Commit: JSONRepresentable {
    
    private enum JSONKey: String {
        case identifier, timestamp, repositoryIdentifier, predecessorIdentifier, mergedPredecessorIdentifier
    }
    
    init(withJSONRepresentation json: Any) throws {
        guard
            let json = json as? [String:Any],
            let identifier = json[JSONKey.identifier.rawValue] as? CommitIdentifier,
            let timestamp = json[JSONKey.timestamp.rawValue] as? TimeInterval,
            let repositoryIdentifier = json[JSONKey.repositoryIdentifier.rawValue] as? RepositoryIdentifier else {
            throw JSONSerializationError.invalidCommit(reason: "No valid commit")
        }
        
        self.identifier = identifier
        self.repositoryIdentifier = repositoryIdentifier
        self.timestamp = timestamp
        
        if let predecessorIdentifier = json[JSONKey.predecessorIdentifier.rawValue] as? CommitIdentifier {
            let mergedIdentifier = json[JSONKey.mergedPredecessorIdentifier.rawValue] as? CommitIdentifier
            self.lineage = CommitLineage(predecessor: predecessorIdentifier, mergedPredecessor: mergedIdentifier)
        }
        else {
            self.lineage = nil
        }
    }
    
    func JSONRepresentation() -> Any {
        var result = [String:Any]()
        result[JSONKey.identifier.rawValue] = identifier
        result[JSONKey.timestamp.rawValue] = timestamp
        result[JSONKey.repositoryIdentifier.rawValue] = repositoryIdentifier
        result[JSONKey.predecessorIdentifier.rawValue] = lineage?.predecessorIdentifier
        result[JSONKey.mergedPredecessorIdentifier.rawValue] = lineage?.mergedPredecessorIdentifier
        return result
    }
}


extension History: JSONRepresentable {
    
    private enum JSONKey: String {
        case repositoryIdentifier, commitsByIdentifier, head, detachedHeads, remoteHeads
    }
    
    init(withJSONRepresentation json: Any) throws {
        guard
            let json = json as? [String:Any],
            let repositoryIdentifier = json[JSONKey.repositoryIdentifier.rawValue] as? RepositoryIdentifier,
            let commitsByIdentifier = json[JSONKey.commitsByIdentifier.rawValue] as? [CommitIdentifier: Any],
            let detachedHeads = json[JSONKey.detachedHeads.rawValue] as? [CommitIdentifier],
            let remoteHeads = json[JSONKey.remoteHeads.rawValue] as? [CommitIdentifier] else {
            throw JSONSerializationError.invalidHistory(reason: "No valid JSON history")
        }
        
        self.repositoryIdentifier = repositoryIdentifier
        self.detachedHeads = Set(detachedHeads)
        self.remoteHeads = Set(remoteHeads)
        self.head = json[JSONKey.head.rawValue] as? CommitIdentifier
        self.commitsByIdentifier = try commitsByIdentifier.mapValues { try Commit(withJSONRepresentation: $1) }
    }
    
    func JSONRepresentation() -> Any {
        var result = [String:Any]()
        result[JSONKey.repositoryIdentifier.rawValue] = repositoryIdentifier
        result[JSONKey.head.rawValue] = head
        result[JSONKey.detachedHeads.rawValue] = Array(detachedHeads)
        result[JSONKey.remoteHeads.rawValue] = Array(remoteHeads)
        result[JSONKey.commitsByIdentifier.rawValue] = commitsByIdentifier.mapValues { $1.JSONRepresentation() }
        return result
    }

}
