//
//  MonolithicRepository
//  Impeller
//
//  Created by Drew McCormack on 08/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

import Foundation


/// All data is in memory. This class does not persist data to disk,
/// but other classes can be used to do that.
public class MonolithicRepository: LocalRepository, Exchangable {
    public var uniqueIdentifier: UniqueIdentifier = uuid()
    private let queue = DispatchQueue(label: "impeller.monolithicRepository")
    private var forest = Forest()
    
    private var commitTimestamp = Date.distantPast.timeIntervalSinceReferenceDate

    public init() {}
    
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
    public func commit<T:Repositable>(_ value: inout T, resolvingConflictsWith conflictResolver: ConflictResolver? = nil) {
        queue.sync {
            performCommit(&value, resolvingConflictsWith: conflictResolver)
        }
    }
    
    private func performCommit<T:Repositable>(_ value: inout T, resolvingConflictsWith conflictResolver: ConflictResolver? = nil) {
        let planter = ForestPlanter(withRoot: value)
        let commitForest = planter.forest
        let rootRef = ValueTreePlanter(value).valueTree.valueTreeReference
        let plantedTree = PlantedValueTree(forest: commitForest, root: rootRef)
        forest.merge(plantedTree, resolvingConflictsWith: conflictResolver)
    }
    
    public func delete<T:Repositable>(_ root: inout T) {
        queue.sync {
            // First merge in-memory and repo values, then delete
            self.performCommit(&root)
            self.performDelete(&root)
        }
    }
    
    private func performDelete<T:Repositable>(_ root: inout T) {
        let rootTree = ValueTreePlanter(root).valueTree
        forest.deleteValueTrees(descendentFrom: rootTree.valueTreeReference)
    }
    
    public func fetchValue<T:Repositable>(identifiedBy uniqueIdentifier:UniqueIdentifier) -> T? {
        var result: T?
        queue.sync {
            let ref = ValueTreeReference(uniqueIdentifier: uniqueIdentifier, repositedType: T.repositedType)
            let valueTree = forest.valueTree(at: ref)
            
            // TODO: Convert value tree into repositable
        }
        return result
    }
    
    public func push(changesSince cursor: Cursor?, completionHandler completion: @escaping (Error?, [ValueTree], Cursor?)->Void) {
        queue.async {
            let timestampCursor = cursor as? TimestampCursor
            var maximumTimestamp = timestampCursor?.timestamp ?? Date.distantPast.timeIntervalSinceReferenceDate
            var valueTrees = [ValueTree]()
            for valueTree in self.forest {
                let time = valueTree.metadata.timestamp
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
    
    public func read<T:RepositablePrimitive>(_ key:String) -> T? {
        if  let property = currentTreeProperty(key),
            let primitive = property.asPrimitive() {
            return T(primitive)
        }
        else {
            return nil
        }
    }
    
    public func read<T:RepositablePrimitive>(optionalFor key:String) -> T?? {
        if  let property = currentTreeProperty(key),
            let optionalPrimitive = property.asOptionalPrimitive() {
            if let primitive = optionalPrimitive {
                return T(primitive)
            }
            else {
                return nil as T?
            }
        }
        else {
            return nil
        }
    }
    
    public func read<T:RepositablePrimitive>(_ key:String) -> [T]? {
        if  let property = currentTreeProperty(key),
            let primitives = property.asPrimitives() {
            return primitives.flatMap { T($0) }
        }
        else {
            return nil
        }
    }
    
    public func read<T:Repositable>(_ key:String) -> T? {
        if  let property = currentTreeProperty(key),
            let reference = property.asValueTreeReference() {
            return repositableValue(identifiedBy: reference.uniqueIdentifier)
        }
        else {
            return nil
        }
    }
    
    public func read<T:Repositable>(optionalFor key:String) -> T?? {
        if  let property = currentTreeProperty(key),
            let optionalReference = property.asOptionalValueTreeReference(),
            let reference = optionalReference {
            return repositableValue(identifiedBy: reference.uniqueIdentifier)
        }
        else {
            return nil
        }
    }
    
    public func read<T:Repositable>(_ key:String) -> [T]? {
        if  let property = currentTreeProperty(key),
            let references = property.asValueTreeReferences() {
            return references.map { repositableValue(identifiedBy: $0.uniqueIdentifier)! }
        }
        else {
            return nil
        }
    }

}
