//
//  Forest.swift
//  Impeller
//
//  Created by Drew McCormack on 05/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

public class ConflictResolver {
//    func resolved(fromConflictOf valueTree: ValueTree, with otherValueTree: ValueTree) -> ValueTree {
//        return valueTree.metadata.commitTimestamp >= otherValueTree.metadata.commitTimestamp ? valueTree : otherValueTree
//    }
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
    
    public mutating func insertValueTrees(descendantFrom root: PlantedValueTree) {
        let rootForest = root.forest
        for path in root {
            let tree = rootForest.valueTree(at: path.valueTreeReference)!
            update(tree)
        }
    }
    
    public mutating func deleteValueTrees(descendantFrom reference: ValueTreeReference) {
        let timestamp = Date.timeIntervalSinceReferenceDate
        let plantedTree = PlantedValueTree(forest: self, root: reference)
        for path in plantedTree {
            var tree = valueTree(at: path.valueTreeReference)!
            tree.metadata.isDeleted = true
//            tree.metadata.commitTimestamp = timestamp
            update(tree)
        }
        
        // TODO: Need to remove the deleted tree from any ancestors. Have to fetch ancestors and update appropriately.
    }
    
    // Inserts a value tree, or updates an existing one
    public mutating func update(_ valueTree: ValueTree) {
        let ref = valueTree.valueTreeReference
        valueTreesByReference[ref] = valueTree
    }
    
    public mutating func merge(_ plantedValueTree: PlantedValueTree, resolvingConflictsWith conflictResolver: ConflictResolver = ConflictResolver()) {
//        let timestamp = Date.timeIntervalSinceReferenceDate
//        
//        // Gather identifiers for trees before the merge from both forests
//        var treeRefsPriorToMerge = Set<ValueTreeReference>()
//        let existingPlantedValueTree = PlantedValueTree(forest: self, root: plantedValueTree.root)
//        for path in existingPlantedValueTree {
//            treeRefsPriorToMerge.insert(path.valueTreeReference)
//        }
//        for path in plantedValueTree {
//            treeRefsPriorToMerge.insert(path.valueTreeReference)
//        }
//        
//        // Merge
//        for path in plantedValueTree {
//            let ref = path.valueTreeReference
//            var resolvedTree: ValueTree!
//            var updateVersion = false
//            var changed = false
//            
//            let treeInOtherForest = plantedValueTree.forest.valueTree(at: ref)!
//            let treeInThisForest = valueTree(at: ref)
//            if treeInThisForest == nil {
//                // Does not exist in this forest. Just copy it over.
//                resolvedTree = treeInOtherForest
//                changed = true
//            }
//            else if treeInThisForest == treeInOtherForest {
//                // Values unchanged from store. Don't commit data again
//                changed = false
//            }
//            else if treeInOtherForest.metadata.version == treeInThisForest!.metadata.version {
//                // Trees differ, but have the same version. So assume the new tree has uncommited changes, overriding the stored value.
//                resolvedTree = treeInOtherForest
//                updateVersion = true
//                changed = true
//            }
//            else {
//                // Conflict with store. Resolve.
//                resolvedTree = conflictResolver.resolved(fromConflictOf: treeInThisForest!, with: treeInOtherForest)
//                updateVersion = true
//                changed = true
//            }
//            
//            if changed {
//                if updateVersion {  resolvedTree.metadata.generateVersion() }
//                resolvedTree.metadata.commitTimestamp = timestamp
//                update(resolvedTree)
//            }
//        }
//        
//        // Determine what refs exist in the resolved tree
//        var treeRefsPostMerge = Set<ValueTreeReference>()
//        let resolvedPlantedValueTree = PlantedValueTree(forest: self, root: plantedValueTree.root)
//        for ref in resolvedPlantedValueTree {
//            treeRefsPostMerge.insert(ref)
//        }
//        
//        // Delete orphans
//        let orphanRefs = treeRefsPriorToMerge.subtracting(treeRefsPostMerge)
//        for orphanRef in orphanRefs {
//            var orphan = valueTree(at: orphanRef)!
//            orphan.metadata.isDeleted = true
//            orphan.metadata.commitTimestamp = timestamp
//            orphan.metadata.generateVersion()
//            update(orphan)
//        }
    }
    
    public func valueTree(at reference: ValueTreeReference) -> ValueTree? {
        return valueTreesByReference[reference]
    }
    
//    public func valueTrees(changedSince timestamp: TimeInterval) -> [ValueTree] {
//        var valueTrees = [ValueTree]()
//        for (_, valueTree) in self.valueTreesByReference {
//            let time = valueTree.metadata.commitTimestamp
//            if timestamp <= time {
//                valueTrees.append(valueTree)
//            }
//        }
//        return valueTrees
//    }
    
}
