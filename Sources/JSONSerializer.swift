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
            JSONKey.version.rawValue : metadata.version]
        json[JSONKey.metadata.rawValue] = metadataDict
        json[JSONKey.propertiesByName.rawValue] = propertiesByName.mapValues { property in
            return property.asJSONObject()
        }
        return json as AnyObject
    }
    
        
  /*
    private var propertiesByName = [String:Property]() */
    
}


extension Property: JSONRepresentable {
    
    init(withJSONObject jsonObject: AnyObject) throws {
        
    }
    
    func asJSONObject() -> AnyObject {
        
    }
    
}
