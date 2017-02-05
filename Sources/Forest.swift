//
//  Forest.swift
//  Impeller
//
//  Created by Drew McCormack on 05/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

public protocol ConflictResolver {
    func resolved(fromConflictOf valueTree: ValueTree, with otherValueTree: ValueTree) -> ValueTree
}


public protocol ForestSerializer {
    func load(from url:URL) throws -> Forest
    func save(_ forest:Forest, to url:URL) throws
}


public struct Forest: Sequence {
    private var valueTreesByReference = [ValueTreeReference:ValueTree]()
    
    public init() {}
    
    public var absenteeProvider: (([ValueTreeReference]) -> [ValueTree?])?
    
    public func makeIterator() -> ForestRanger {
        
    }
    
    public mutating func deleteValueTrees(descendentFrom reference: ValueTreeReference) {
    }
    
    // Inserts a value tree, or updates an existing one
    public mutating func update(_ valueTree: ValueTree) {
        let ref = valueTree.valueTreeReference
        valueTreesByReference[ref] = valueTree
    }
    
    public func valueTree(at reference: ValueTreeReference) -> ValueTree? {
        return valueTreesByReference[reference]
    }
    
    public func merge(in valueTree: ValueTree, resolvingConflictsWith conflictResolver: ConflictResolver) {
    }
    
    public func valueTrees(changeedSince timestamp: TimeInterval) -> [ValueTree] {
        var valueTrees = [ValueTree]()
        for (_, valueTree) in self.valueTreesByReference {
            let time = valueTree.metadata.timestamp
            if timestamp <= time {
                valueTrees.append(valueTree)
            }
        }
        return valueTrees
    }
    
}
