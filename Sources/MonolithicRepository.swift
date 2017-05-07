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
    var forest = Forest()
    var history: History
    
    public init() {
        history = History(repositoryIdentifier: uniqueIdentifier)
    }    
    
    /// Resolves conflicts and commits, and sets the value on out to resolved value.
    public func commit<T:Repositable>(_ value: inout T, resolvingConflictsWith conflictResolver: ConflictResolver = ConflictResolver()) {
        queue.sync {
            performCommit(&value)
            
            // TODO: Check here if the committed value is still the head. If not, merge with head.
            // Perhaps we can add a merge method to planted tree. It could work recursively.
        }
    }
    
    private func performCommit<T:Repositable>(_ value: inout T) {
        // Plant new values in a temporary commit forest
        let planter = ForestPlanter(withRoot: value)
        let commitForest = planter.forest
        let commitPlantedTree = PlantedValueTree(forest: commitForest, root: planter.rootReference)
        
        // Fetched commit
        let commitRoot = commitForest.valueTree(at: planter.rootReference)!
        
        // Get tree from our forest, as it was fetched.
        // If the tree is new, set commit ids on all descendants, 
        // and commit it directly to our forest
        guard
            let headWhenFetched = commitRoot.metadata.headWhenFetched,
            let fetchRoot = forest.valueTree(at: planter.rootReference) else {
            let newCommit = history.commitHead(basedOn: nil)
            commit(newlyInsertedTree: commitPlantedTree, for: newCommit.identifier)
                
            let newRootRef = ValueTreeReference(identity: commitPlantedTree.root.identity, commitIdentifier: newCommit.identifier)
            let plantedTree = PlantedValueTree(forest: forest, root: newRootRef)
            value = harvest(plantedTree, forHead: newCommit.identifier)
            
            return
        }
        
        // Determine which value trees have changed
        // Go through and compare new value trees with old values, to determine what changed.
        // Ancestors of changed trees are also considered changed, as the value tree references they contain are no 
        // longer valid. Ie they must reference the newly changed trees.
        var updatedRefs: Set<ValueTreeReference> = []
        let rootAncestryIdentities = fetchRoot.metadata.ancestry!
        let rootAncestryRefs = rootAncestryIdentities.map { valueTreeReference(for: $0, applicableAtCommit: headWhenFetched)! }
        var ancestryByNewRef: [ValueTreeReference:[ValueTreeIdentity]] = [:]
        for path in commitPlantedTree {
            let ref = path.valueTreeReference
            let commitValueTree = commitForest.valueTree(at: ref)!
            if let fetchValueTree = forest.valueTree(at: ref) {
                if fetchValueTree.propertiesByName != commitValueTree.propertiesByName {
                    updatedRefs.formUnion(path.pathFromRoot) // Tree and ancestors up to commit root
                    updatedRefs.formUnion(rootAncestryRefs)  // Ancestors of root
                }
            }
            else {
                ancestryByNewRef[ref] = rootAncestryIdentities + path.ancestorReferences.map { $0.identity }
            }
        }
        
        // If there are no changes, don't commit anything.
        guard ancestryByNewRef.count + updatedRefs.count > 0 else { return }
        
        // Prepare a commit
        let newCommit = history.commitHead(basedOn: headWhenFetched)
        
        // Should be no overlap between new trees, and changed trees
        assert(updatedRefs.isDisjoint(with: Set(ancestryByNewRef.keys)))
        
        // Determine which trees have been orphaned. Update them, and insert new copy in forest.
        let fetchPlantedTree = PlantedValueTree(forest: forest, root: fetchRoot.valueTreeReference)
        for path in fetchPlantedTree {
            let ref = path.valueTreeReference
            if commitForest.valueTree(at: ref) == nil {
                var orphan = forest.valueTree(at: ref)!
                
                // Update child references. If a value tree is orphaned, so are all its
                // descendants, so all child references have the new commit identifier.
                orphan.updateChildReferences {
                    ValueTreeReference(identity: $0.identity, commitIdentifier: newCommit.identifier)
                }
                
                // Update metadata
                var newMetadata = orphan.metadata
                newMetadata.commitIdentifier = newCommit.identifier
                newMetadata.isDeleted = true
                orphan.metadata = newMetadata
            
                forest.update(orphan)
            }
        }
        
        // Add all new trees.
        for (ref, ancestry) in ancestryByNewRef {
            var newValueTree = commitForest.valueTree(at: ref)!
            
            // Update child references. All children must also be new, so they have the new commit identifier.
            newValueTree.updateChildReferences {
                ValueTreeReference(identity: $0.identity, commitIdentifier: newCommit.identifier)
            }
            
            // Update metadata
            var newMetadata = newValueTree.metadata
            newMetadata.commitIdentifier = newCommit.identifier
            newMetadata.ancestry = ancestry
            newValueTree.metadata = newMetadata
            
            forest.update(newValueTree)
        }
        
        // Insert new versions of updated trees.
        let identitiesOfUpdated = Set(updatedRefs.map({ $0.identity }))
        let identitiesOfNew = Set(ancestryByNewRef.keys.map({ $0.identity }))
        let identitiesOfNewlyCommitted = identitiesOfUpdated.union(identitiesOfNew)
        for ref in updatedRefs {
            // Most trees will be in the commit forest, but it is possible that ancestors 
            // are not. In that case, fetch them from the main forest.
            var newValueTree = commitForest.valueTree(at: ref) ?? forest.valueTree(at: ref)!

            // Update child references.
            newValueTree.updateChildReferences {
                let newCommitId = identitiesOfNewlyCommitted.contains($0.identity) ? newCommit.identifier : $0.commitIdentifier
                return ValueTreeReference(identity: $0.identity, commitIdentifier: newCommitId)
            }
            
            // Update metadata
            var newMetadata = newValueTree.metadata
            newMetadata.commitIdentifier = newCommit.identifier
            newValueTree.metadata = newMetadata
            
            forest.update(newValueTree)
        }
        
        // Harvest
        let newRootRef = ValueTreeReference(identity: commitPlantedTree.root.identity, commitIdentifier: newCommit.identifier)
        let plantedTree = PlantedValueTree(forest: forest, root: newRootRef)
        value = harvest(plantedTree, forHead: newCommit.identifier)
    }
    
    private func commit(newlyInsertedTree plantedTree: PlantedValueTree, for commitIdentifier: CommitIdentifier) {
        var finalizedForest = Forest()
        
        // Create new trees
        for path in plantedTree {
            var tree = plantedTree.forest.valueTree(at: path.valueTreeReference)!
            
            // Update child refs to include the commit id
            tree.updateChildReferences {
                ValueTreeReference(identity: $0.identity, commitIdentifier: commitIdentifier)
            }
            
            // Update metadata
            var newMetadata = tree.metadata
            newMetadata.commitIdentifier = commitIdentifier
            newMetadata.ancestry = path.ancestorReferences.map { $0.identity }
            tree.metadata = newMetadata
            
            finalizedForest.update(tree)
        }
        
        // New root reference
        let oldRootRef = plantedTree.root
        let rootRef = ValueTreeReference(identity: oldRootRef.identity, commitIdentifier: commitIdentifier)
        
        // Insert new value trees
        let newPlantedTree = PlantedValueTree(forest: finalizedForest, root: rootRef)
        forest.insertValueTrees(descendantFrom: newPlantedTree)
    }
    
    public func delete<T:Repositable>(_ root: inout T, resolvingConflictsWith conflictResolver: ConflictResolver = ConflictResolver()) {
        queue.sync {
            // First merge in-memory and repo values, then delete
            self.performCommit(&root)
            self.performDelete(&root)
            
            // TODO: Use conflict resolver to merge with other heads here
        }
    }
    
    private func performDelete<T:Repositable>(_ root: inout T) {
        let rootTree = ValueTreePlanter(repositable: root).valueTree
        forest.deleteValueTrees(descendantFrom: rootTree.valueTreeReference)
    }
    
    private func valueTreeReference(for identity: ValueTreeIdentity, applicableAtCommit commitIdentifier: CommitIdentifier) -> ValueTreeReference? {
        // Move back in history from commit until a value tree is found with the right identity.
        var result: ValueTreeReference?
        history.visitPredecessors(ofCommitIdentifiedBy: commitIdentifier) { commit in
            let ref = ValueTreeReference(identity: identity, commitIdentifier: commit.identifier)
            if forest.valueTree(at: ref) != nil {
                result = ref
                return false
            }
            return true
        }
        return result
    }
    
    public func fetchValue<T:Repositable>(identifiedBy uniqueIdentifier:UniqueIdentifier) -> T? {
        var result: T?
        queue.sync {
            let identity = ValueTreeIdentity(uniqueIdentifier: uniqueIdentifier, repositedType: T.repositedType)
            guard
                let head = history.head,
                let rootRef = valueTreeReference(for: identity, applicableAtCommit: head),
                let valueTree = forest.valueTree(at: rootRef),
                !valueTree.metadata.isDeleted else { return }
            let plantedTree = PlantedValueTree(forest: forest, root: rootRef)
            result = harvest(plantedTree, forHead: head)
        }
        return result
    }
    
    private func harvest<T:Repositable>(_ plantedTree: PlantedValueTree, forHead head: CommitIdentifier) -> T {
        // Set the headWhenFetched for the whole tree. Use a temporary forest to store new values.
        let harvestPlantedTree = plantedTree.map {
            var new = $0
            new.metadata.headWhenFetched = head
            return new
        }
        
        // Harvest
        let harvestForest = harvestPlantedTree.forest
        let rootTree = harvestForest.valueTree(at: harvestPlantedTree.root)!
        let harvester = ForestHarvester(forest: harvestForest)
        let repositable:T = harvester.harvest(rootTree)
        
        return repositable
    }
    
    public func push(changesSince cursor: Cursor?, completionHandler completion: @escaping (Error?, [ValueTree], Cursor?)->Void) {
//        queue.async {
//            let timestampCursor = cursor as? TimestampCursor
//            var maximumTimestamp = timestampCursor?.timestamp ?? Date.distantPast.timeIntervalSinceReferenceDate
//            var valueTrees = [ValueTree]()
//            for valueTree in self.forest {
//                let time = valueTree.metadata.commitTimestamp
//                if timestampCursor == nil || timestampCursor!.timestamp <= time {
//                    valueTrees.append(valueTree)
//                    maximumTimestamp = max(maximumTimestamp, time)
//                }
//            }
//            DispatchQueue.main.async {
//                completion(nil, valueTrees, TimestampCursor(timestamp: maximumTimestamp))
//            }
//        }
    }
    
    public func pull(_ valueTrees: [ValueTree], completionHandler completion: @escaping CompletionHandler) {
//        queue.async {
//            for newTree in valueTrees {
//                let reference = ValueTreeReference(uniqueIdentifier: newTree.metadata.uniqueIdentifier, repositedType: newTree.repositedType)
//                let mergedTree = newTree.merged(with: self.forest.valueTree(at: reference))
//                self.forest.update(mergedTree)
//            }
//            DispatchQueue.main.async {
//                completion(nil)
//            }
//        }
    }
    
    public func makeCursor(fromData data: Data) -> Cursor? {
        return TimestampCursor(data: data)
    }

}
