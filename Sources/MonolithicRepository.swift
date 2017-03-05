//
//  MonolithicRepository
//  Impeller
//
//  Created by Drew McCormack on 08/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

/// All data is in memory. This class does not persist data to disk,
/// but other classes can be used to do that.
public class MonolithicRepository: LocalRepository, Exchangable {
    public var uniqueIdentifier: UniqueIdentifier = uuid()
    private let queue = DispatchQueue(label: "impeller.monolithicRepository")
    private var forest = Forest()
    private var history: History
    
    public init() {
        history = History(repositoryIdentifier: uniqueIdentifier)
    }
    
    public func load(from url:URL, with serializer: ForestSerializer) throws {
        try queue.sync {
            try forest = serializer.load(from:url)
        }
    }
    
    public func save(to url:URL, with serializer: ForestSerializer) throws {
        try queue.sync {
            try serializer.save(forest, to:url)
        }
    }
    
    /// Resolves conflicts and commits, and sets the value on out to resolved value.
    public func commit<T:Repositable>(_ value: inout T, resolvingConflictsWith conflictResolver: ConflictResolver = ConflictResolver()) {
        queue.sync {
            performCommit(&value, resolvingConflictsWith: conflictResolver)
        }
    }
    
    private func performCommit<T:Repositable>(_ value: inout T, resolvingConflictsWith conflictResolver: ConflictResolver) {
        // Plant new values
        let planter = ForestPlanter(withRoot: value)
        let commitForest = planter.forest
        let rootRef = ValueTreePlanter(repositable: value).valueTree.valueTreeReference
        let plantedTree = PlantedValueTree(forest: commitForest, root: rootRef)
        
        // Get planted tree as fetched
        
        // Determine which value trees have changed, and which should be deleted
        
        // If there are changes, create commit root value tree
        
        // Determine the absolute root of the planted tree
    
        // Merge into forest
        forest.merge(plantedTree, resolvingConflictsWith: conflictResolver)
        
        // Harvest
        let newValueTree = forest.valueTree(at: rootRef)!
        let harvester = ForestHarvester(forest: forest)
        value = harvester.harvest(newValueTree)
    }
    
    public func delete<T:Repositable>(_ root: inout T, resolvingConflictsWith conflictResolver: ConflictResolver = ConflictResolver()) {
        queue.sync {
            // First merge in-memory and repo values, then delete
            self.performCommit(&root, resolvingConflictsWith: conflictResolver)
            self.performDelete(&root)
        }
    }
    
    private func performDelete<T:Repositable>(_ root: inout T) {
        let rootTree = ValueTreePlanter(repositable: root).valueTree
        forest.deleteValueTrees(descendentFrom: rootTree.valueTreeReference)
    }
    
    public func fetchValue<T:Repositable>(identifiedBy uniqueIdentifier:UniqueIdentifier) -> T? {
        var result: T?
        queue.sync {
            let ref = ValueTreeReference(uniqueIdentifier: uniqueIdentifier, repositedType: T.repositedType)
            if let valueTree = forest.valueTree(at: ref), !valueTree.metadata.isDeleted {
                let harvester = ForestHarvester(forest: forest)
                let repositable:T = harvester.harvest(valueTree)
                result = repositable
            }
        }
        return result
    }
    
    public func push(changesSince cursor: Cursor?, completionHandler completion: @escaping (Error?, [ValueTree], Cursor?)->Void) {
        queue.async {
            let timestampCursor = cursor as? TimestampCursor
            var maximumTimestamp = timestampCursor?.timestamp ?? Date.distantPast.timeIntervalSinceReferenceDate
            var valueTrees = [ValueTree]()
            for valueTree in self.forest {
                let time = valueTree.metadata.commitTimestamp
                if timestampCursor == nil || timestampCursor!.timestamp <= time {
                    valueTrees.append(valueTree)
                    maximumTimestamp = max(maximumTimestamp, time)
                }
            }
            DispatchQueue.main.async {
                completion(nil, valueTrees, TimestampCursor(timestamp: maximumTimestamp))
            }
        }
    }
    
    public func pull(_ valueTrees: [ValueTree], completionHandler completion: @escaping CompletionHandler) {
        queue.async {
            for newTree in valueTrees {
                let reference = ValueTreeReference(uniqueIdentifier: newTree.metadata.uniqueIdentifier, repositedType: newTree.repositedType)
                let mergedTree = newTree.merged(with: self.forest.valueTree(at: reference))
                self.forest.update(mergedTree)
            }
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    public func makeCursor(fromData data: Data) -> Cursor? {
        return TimestampCursor(data: data)
    }

}
