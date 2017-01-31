//
//  JSONRepository.swift
//  Impeller
//
//  Created by Drew McCormack on 26/01/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation


protocol JSONRepresentable {
    init(withJSONObject jsonObject: AnyObject) throws
    func JSONObject() -> AnyObject
}


public class JSONSerializer: Serializer {
    
    public func load(from url:URL) throws -> [String:ValueTree] {
        fatalError("JSON serialization not implemented yet")
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
    
    public init(withJSONObject jsonObject: AnyObject) throws {
        
    }
    
    public func JSONObject() -> AnyObject {
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
        return json as AnyObject
    }
    
}


extension Property: JSONRepresentable {
    
    public enum JSONKey: String {
        case type, value, referencedType, referencedIdentifier
    }
    
    public init(withJSONObject jsonObject: AnyObject) throws {
        
    }
    
    public func JSONObject() -> AnyObject {
        var result = [String:Any]()
        switch self {
        case .primitive(let primitive):
            result[JSONKey.type.rawValue] = primitive.type.rawValue
            result[JSONKey.value.rawValue] = primitive.value
        case .optionalPrimitive(let primitive):
            if let primitive = primitive {
                result[JSONKey.type.rawValue] = primitive.type.rawValue
                result[JSONKey.value.rawValue] = primitive.value
            }
            else {
                result[JSONKey.type.rawValue] = 0
            }
        case .primitives(let primitives):
            if primitives.count > 0 {
                result[JSONKey.type.rawValue] = primitives.first!.type.rawValue
                result[JSONKey.value.rawValue] = primitives.map { $0.value }
            }
            else {
                result[JSONKey.type.rawValue] = 0
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
                result[JSONKey.referencedIdentifier.rawValue] = refs.map { $0.uniqueIdentifier }
            }
        }
        return result as AnyObject
    }
    
}
