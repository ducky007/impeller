//
//  Metadata.swift
//  Impeller
//
//  Created by Drew McCormack on 08/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

import Foundation


public typealias UniqueIdentifier = String
typealias RepositedVersion = UInt64


public struct Metadata: Equatable {
    
    public enum Key: String {
        case version, timestamp, uniqueIdentifier, isDeleted
    }
        
    public let uniqueIdentifier: UniqueIdentifier
    public internal(set) var timestamp: TimeInterval // When stored
    public internal(set) var isDeleted: Bool
    internal var version: RepositedVersion = 0
    
    public init(uniqueIdentifier: UniqueIdentifier = UUID().uuidString) {
        self.uniqueIdentifier = uniqueIdentifier
        self.timestamp = Date.timeIntervalSinceReferenceDate
        self.isDeleted = false
    }
        
    public static func == (left: Metadata, right: Metadata) -> Bool {
        return left.version == right.version && left.timestamp == right.timestamp && left.uniqueIdentifier == right.uniqueIdentifier && left.isDeleted == right.isDeleted
    }
    
}
