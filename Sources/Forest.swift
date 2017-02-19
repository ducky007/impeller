//
//  Forest.swift
//  Impeller
//
//  Created by Drew McCormack on 05/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

public class ConflictResolver {
    func resolved(fromConflictOf valueTree: ValueTree, with otherValueTree: ValueTree) -> ValueTree {
        return valueTree.metadata.timestamp >= otherValueTree.metadata.timestamp ? valueTree : otherValueTree
    }
}


public protocol ForestSerializer {
    func load(from url:URL) throws -> Forest
    func save(_ forest:Forest, to url:URL) throws
}


public struct Forest: Sequence {
    private var valueTreesByReference = [ValueTreeReference:ValueTree]()
    
    public init() {}
    
    public init(valueTrees: [ValueTree]) {
        for tree in valueTrees {
            self.valueTreesByReference[tree.valueTreeReference] = tree
        }
    }
    
    public var absenteeProvider: (([ValueTreeReference]) -> [ValueTree?])?
    
    public func makeIterator() -> AnyIterator<ValueTree> {
        let trees = Array(valueTreesByReference.values)
        var i = -1
        return AnyIterator {
            i += 1
            return i < trees.count ? trees[i] : nil
        }
    }
    
    public mutating func deleteValueTrees(descendentFrom reference: ValueTreeReference) {
        let timestamp = Date.timeIntervalSinceReferenceDate
        let plantedTree = PlantedValueTree(forest: self, root: reference)
        for ref in plantedTree {
            var tree = valueTree(at: ref)!
            tree.metadata.isDeleted = true
            tree.metadata.timestamp = timestamp
            update(tree)
        }
    }
    
    // Inserts a value tree, or updates an existing one
    public mutating func update(_ valueTree: ValueTree) {
        let ref = valueTree.valueTreeReference
        valueTreesByReference[ref] = valueTree
    }
    
    public mutating func merge(_ plantedValueTree: PlantedValueTree, resolvingConflictsWith conflictResolver: ConflictResolver = ConflictResolver()) {
        let timestamp = Date.timeIntervalSinceReferenceDate
        
        // Gather identifiers for trees before the merge from both forests
        var treeRefsPriorToMerge = Set<ValueTreeReference>()
        let existingPlantedValueTree = PlantedValueTree(forest: self, root: plantedValueTree.root)
        for ref in existingPlantedValueTree {
            treeRefsPriorToMerge.insert(ref)
        }
        for ref in plantedValueTree {
            treeRefsPriorToMerge.insert(ref)
        }
        
        // Merge
        for ref in plantedValueTree {
            var resolvedTree: ValueTree!
            var resolvedVersion: RepositedVersion = 0
            var resolvedTimestamp = timestamp
            var changed = true
            
            let treeInOtherForest = plantedValueTree.forest.valueTree(at: ref)!
            let treeInThisForest = valueTree(at: ref)
            if treeInThisForest == nil {
                // Does not exist in this forest. Just copy it over.
                resolvedTree = treeInOtherForest
                resolvedVersion = treeInOtherForest.metadata.version
                resolvedTimestamp = treeInOtherForest.metadata.timestamp
            }
            else if treeInThisForest == treeInOtherForest {
                // Values unchanged from store. Don't commit data again
                resolvedTree = treeInOtherForest
                resolvedVersion = treeInOtherForest.metadata.version
                resolvedTimestamp = treeInOtherForest.metadata.timestamp
                changed = false
            }
            else if treeInOtherForest.metadata.version == treeInThisForest!.metadata.version {
                // Store has not changed since the base value was taken, so just commit the new value directly
                resolvedTree = treeInOtherForest
                resolvedVersion = treeInOtherForest.metadata.version + 1
            }
            else {
                // Conflict with store. Resolve.
                resolvedTree = conflictResolver.resolved(fromConflictOf: treeInThisForest!, with: treeInOtherForest)
                resolvedVersion = Swift.max(treeInOtherForest.metadata.version, treeInThisForest!.metadata.version) + 1
            }
            
            if changed {
                resolvedTree.metadata.timestamp = resolvedTimestamp
                resolvedTree.metadata.version = resolvedVersion
                update(resolvedTree)
            }
        }
        
        // Determine what refs exist in the resolved tree
        var treeRefsPostMerge = Set<ValueTreeReference>()
        let resolvedPlantedValueTree = PlantedValueTree(forest: self, root: plantedValueTree.root)
        for ref in resolvedPlantedValueTree {
            treeRefsPostMerge.insert(ref)
        }
        
        // Delete orphans
        let orphanRefs = treeRefsPriorToMerge.subtracting(treeRefsPostMerge)
        for orphanRef in orphanRefs {
            var orphan = valueTree(at: orphanRef)!
            orphan.metadata.isDeleted = true
            orphan.metadata.timestamp = timestamp
            orphan.metadata.version += 1
            update(orphan)
        }
    }
    
    public func valueTree(at reference: ValueTreeReference) -> ValueTree? {
        return valueTreesByReference[reference]
    }
    
    public func valueTrees(changedSince timestamp: TimeInterval) -> [ValueTree] {
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
