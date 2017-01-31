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
}


protocol JSONRepresentable {
    init(withJSONObject jsonObject: Any) throws
    func JSONObject() -> Any
}


public class JSONSerializer: Serializer {
    
    public func load(from url:URL) throws -> [String:ValueTree] {
        let data = try Data(contentsOf: url)
        guard let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
            throw JSONSerializationError.invalidFormat(reason: "JSON root was not a dictionary")
        }
        return try dict.mapValues { try ValueTree(withJSONObject: $0) }
    }
    
    public func save(_ valueTreesByKey:[String:ValueTree], to url:URL) throws {
        let json = valueTreesByKey.mapValues { $0.JSONObject() }
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        try data.write(to: url)
    }
    
}


extension ValueTree: JSONRepresentable {
    
    public enum JSONKey: String {
        case metadata, storedType, uniqueIdentifier, timestamp, isDeleted, version, propertiesByName
    }
    
    public init(withJSONObject jsonObject: Any) throws {
        guard let jsonObject = jsonObject as? [String:Any] else {
            throw JSONSerializationError.invalidFormat(reason: "No root dictionary in JSON")
        }
        guard
            let id = jsonObject[JSONKey.uniqueIdentifier.rawValue] as? String,
            let storedType = jsonObject[JSONKey.storedType.rawValue] as? StoredType,
            let timestamp = jsonObject[JSONKey.timestamp.rawValue] as? TimeInterval,
            let isDeleted = jsonObject[JSONKey.isDeleted.rawValue] as? Bool,
            let version = jsonObject[JSONKey.version.rawValue] as? StoredVersion else {
            throw JSONSerializationError.invalidMetadata
        }
        var metadata = Metadata(uniqueIdentifier: id)
        metadata.timestamp = timestamp
        metadata.isDeleted = isDeleted
        metadata.version = version
        
        self.storedType = storedType
        self.metadata = metadata
        
        guard let propertiesByName = jsonObject[JSONKey.propertiesByName.rawValue] as? [String:Any] else {
            throw JSONSerializationError.invalidFormat(reason: "No properties dictionary found for object")
        }
        self.propertiesByName = try propertiesByName.mapValues {
            try Property(withJSONObject: $0 as AnyObject)
        }
    }
    
    public func JSONObject() -> Any {
        var json = [String:Any]()
        let metadataDict: [String:Any] = [
            JSONKey.storedType.rawValue : storedType,
            JSONKey.uniqueIdentifier.rawValue : metadata.uniqueIdentifier,
            JSONKey.timestamp.rawValue : metadata.timestamp,
            JSONKey.isDeleted.rawValue : metadata.isDeleted,
            JSONKey.version.rawValue : metadata.version
        ]
        json[JSONKey.metadata.rawValue] = metadataDict
        json[JSONKey.propertiesByName.rawValue] = propertiesByName.mapValues { property in
            return property.JSONObject()
        }
        return json
    }
    
}


extension Property: JSONRepresentable {
    
    public enum JSONKey: String {
        case propertyType, primitiveType, value, referencedType, referencedIdentifier, referencedIdentifiers
    }
    
    public init(withJSONObject jsonObject: Any) throws {
        guard
            let jsonObject = jsonObject as? [String:Any],
            let propertyTypeInt = jsonObject[JSONKey.propertyType.rawValue] as? Int,
            let propertyType = PropertyType(rawValue: propertyTypeInt) else {
            throw JSONSerializationError.invalidProperty(reason: "No valid property type")
        }

        let primitiveTypeInt = jsonObject[JSONKey.primitiveType.rawValue] as? Int
        let primitiveType = primitiveTypeInt != nil ? PrimitiveType(rawValue: primitiveTypeInt!) : nil

        switch propertyType {
        case .primitive:
            guard
                let primitiveType = primitiveType,
                let value = jsonObject[JSONKey.value.rawValue] else {
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
                    let value = jsonObject[JSONKey.value.rawValue] else {
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
                    let value = jsonObject[JSONKey.value.rawValue] as? [Any] else {
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
            self = try Property(withReferenceDictionary: jsonObject)
        case .optionalValueTreeReference:
            if let referencedType = jsonObject[JSONKey.referencedType.rawValue] as? Int, referencedType == 0 {
                self = .optionalValueTreeReference(nil)
            }
            else {
                self = try Property(withReferenceDictionary: jsonObject)
            }
        case .valueTreeReferences:
            if let referencedType = jsonObject[JSONKey.referencedType.rawValue] as? Int, referencedType == 0 {
                self = .valueTreeReferences([])
            }
            else {
                guard
                    let referencedType = jsonObject[JSONKey.referencedType.rawValue] as? String,
                    let referencedIdentifiers = jsonObject[JSONKey.referencedIdentifiers.rawValue] as? [String] else {
                    throw JSONSerializationError.invalidProperty(reason: "No primitive type or value found")
                }
                let refs = referencedIdentifiers.map { ValueTreeReference(uniqueIdentifier: $0, storedType: referencedType) }
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
        let ref = ValueTreeReference(uniqueIdentifier: referencedIdentifier, storedType: referencedType)
        self = .valueTreeReference(ref)
    }
    
    public func JSONObject() -> Any {
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
            result[JSONKey.referencedType.rawValue] = ref.storedType
            result[JSONKey.referencedIdentifier.rawValue] = ref.uniqueIdentifier
        case .optionalValueTreeReference(let ref):
            if let ref = ref {
                result[JSONKey.referencedType.rawValue] = ref.storedType
                result[JSONKey.referencedIdentifier.rawValue] = ref.uniqueIdentifier
            }
            else {
                result[JSONKey.referencedType.rawValue] = 0
            }
        case .valueTreeReferences(let refs):
            if refs.count > 0 {
                result[JSONKey.referencedType.rawValue] = refs.first!.storedType
                result[JSONKey.referencedIdentifiers.rawValue] = refs.map { $0.uniqueIdentifier }
            }
            else {
                result[JSONKey.referencedType.rawValue] = 0
            }
        }
        
        return result as AnyObject
    }
    
}
