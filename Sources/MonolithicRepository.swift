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
            result = repositableValue(identifiedBy: uniqueIdentifier)
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
    
//    public func write<T:RepositablePrimitive>(_ value:T, for key:String) {
//        guard !identifiersOfUnchanged.contains(currentTreeReference.uniqueIdentifier) else { return }
//        let primitive = Primitive(value: value)
//        let property: Property = .primitive(primitive!)
//        valueTreesByKey[currentValueTreeKey]!.set(key, to: property)
//    }
//    
//    public func write<T:RepositablePrimitive>(_ value:T?, for key:String) {
//        guard !identifiersOfUnchanged.contains(currentTreeReference.uniqueIdentifier) else { return }
//        let primitive = value != nil ? Primitive(value: value!) : nil
//        let property: Property = .optionalPrimitive(primitive)
//        valueTreesByKey[currentValueTreeKey]!.set(key, to: property)
//    }
//    
//    public func write<T:RepositablePrimitive>(_ values:[T], for key:String) {
//        guard !identifiersOfUnchanged.contains(currentTreeReference.uniqueIdentifier) else { return }
//        let primitives = values.map { Primitive(value: $0)! }
//        let property: Property = .primitives(primitives)
//        valueTreesByKey[currentValueTreeKey]!.set(key, to: property)
//    }
//    
//    public func write<T:Repositable>(_ value: inout T, for key:String) {
//        let reference = ValueTreeReference(uniqueIdentifier: value.metadata.uniqueIdentifier, repositedType: T.repositedType)
//        
//        // Fetch existing store value of descendant, and delete (if it differs from new reference)
//        if let oldReference = valueTreesByKey[currentValueTreeKey]!.get(key)?.asValueTreeReference(), reference != oldReference {
//            var oldValue: T = repositableValue(identifiedBy: oldReference.uniqueIdentifier)!
//            transaction {
//                isDeletionPass = true
//                currentTreeReference = oldReference
//                writeValueAndDescendants(of: &oldValue)
//            }
//        }
//
//        // Store new property
//        let property: Property = .valueTreeReference(reference)
//        valueTreesByKey[currentValueTreeKey]!.set(key, to: property)
//
//        // Recurse to store the new value's data
//        transaction {
//            currentTreeReference = reference
//            writeValueAndDescendants(of: &value)
//        }
//    }
//    
//    public func write<T:Repositable>(_ value: inout T?, for key:String) {
//        var reference: ValueTreeReference?
//        if let value = value {
//            reference = ValueTreeReference(uniqueIdentifier: value.metadata.uniqueIdentifier, repositedType: T.repositedType)
//        }
//        
//        // Fetch existing store value of descendant, and delete
//        if  let oldOptionalReference = valueTreesByKey[currentValueTreeKey]!.get(key)?.asOptionalValueTreeReference(),
//            let oldReference = oldOptionalReference,
//            oldOptionalReference != reference {
//            var oldValue: T = repositableValue(identifiedBy: oldReference.uniqueIdentifier)!
//            transaction {
//                isDeletionPass = true
//                currentTreeReference = oldReference
//                writeValueAndDescendants(of: &oldValue)
//            }
//        }
//        
//        // Store new property
//        let property: Property = .optionalValueTreeReference(reference)
//        valueTreesByKey[currentValueTreeKey]!.set(key, to: property)
//        
//        // Recurse to store the value's data
//        guard value != nil else { return }
//        transaction {
//            currentTreeReference = reference!
//            var updatedValue = value!
//            writeValueAndDescendants(of: &updatedValue)
//            value = updatedValue
//        }
//    }
//    
//    public func write<T:Repositable>(_ values: inout [T], for key:String) {
//        let references = values.map {
//            ValueTreeReference(uniqueIdentifier: $0.metadata.uniqueIdentifier, repositedType: T.repositedType)
//        }
//        
//        // Determine which values get orphaned, and delete them
//        if let oldReferences = valueTreesByKey[currentValueTreeKey]!.get(key)?.asValueTreeReferences() {
//            let orphanedReferences = Set(oldReferences).subtracting(Set(references))
//            for orphanedReference in orphanedReferences {
//                var orphanedValue: T = repositableValue(identifiedBy: orphanedReference.uniqueIdentifier)!
//                transaction {
//                    isDeletionPass = true
//                    currentTreeReference = orphanedReference
//                    writeValueAndDescendants(of: &orphanedValue)
//                }
//            }
//        }
//        
//        // Store new property
//        let property: Property = .valueTreeReferences(references)
//        valueTreesByKey[currentValueTreeKey]!.set(key, to: property)
//        
//        // Recurse to store the value's data
//        var updatedValues = [T]()
//        for (var value, reference) in zip(values, references) {
//            transaction {
//                currentTreeReference = reference
//                writeValueAndDescendants(of: &value)
//                updatedValues.append(value)
//            }
//        }
//        values = updatedValues
//    }
    
//    private func prepareToMakeChanges<T:Repositable>(forRoot value: T) {
//        commitTimestamp = Date.timeIntervalSinceReferenceDate
//        identifiersOfUnchanged = Set<UniqueIdentifier>()
//        currentTreeReference = ValueTreeReference(uniqueIdentifier: value.metadata.uniqueIdentifier, repositedType: T.repositedType)
//        isDeletionPass = false
//        commitContext = nil
//    }
    
//    private func writeValueAndDescendants<T:Repositable>(of value: inout T) {
//        let storeValue:T? = repositableValue(identifiedBy: value.metadata.uniqueIdentifier)
//        if storeValue == nil {
//            valueTreesByKey[currentValueTreeKey] = ValueTree(repositedType: T.repositedType, metadata: value.metadata)
//        }
//        
//        var resolvedValue:T
//        var resolvedVersion:RepositedVersion = 0
//        let resolvedTimestamp = commitTimestamp
//        var changed = true
//        
//        if storeValue == nil {
//            // First commit
//            resolvedValue = value
//            resolvedVersion = 0
//        }
//        else if storeValue!.isRepositoryEquivalent(to: value) && value.metadata == storeValue!.metadata {
//            // Values unchanged from store. Don't commit data again
//            resolvedValue = value
//            resolvedVersion = value.metadata.version
//            changed = false
//        }
//        else if value.metadata.version == storeValue!.metadata.version {
//            // Store has not changed since the base value was taken, so just commit the new value directly
//            resolvedValue = value
//            resolvedVersion = value.metadata.version + 1
//        }
//        else {
//            // Conflict with store. Resolve.
//            resolvedValue = value.resolvedValue(forConflictWith: storeValue!, context: commitContext)
//            resolvedVersion = max(value.metadata.version, storeValue!.metadata.version) + 1
//        }
//        
//        if isDeletionPass && !resolvedValue.metadata.isDeleted {
//            resolvedValue.metadata.isDeleted = true
//            resolvedVersion += 1
//            changed = true
//        }
//        
//        if changed {
//            // Store metadata if changed
//            resolvedValue.metadata.timestamp = resolvedTimestamp
//            resolvedValue.metadata.version = resolvedVersion
//            currentValueTree!.metadata = resolvedValue.metadata
//        }
//        else {
//            // Store id of this unchanged value, so we can skip it in 'store' callbacks
//            identifiersOfUnchanged.insert(value.metadata.uniqueIdentifier)
//        }
//        
//        // Always call write, even if unchanged, to check for changed descendants
//        resolvedValue.write(in: self)
//        value = resolvedValue
//    }
    
    private func repositableValue<T:Repositable>(identifiedBy uniqueIdentifier:UniqueIdentifier) -> T? {
        var result: T?
        transaction {
            currentTreeReference = ValueTreeReference(uniqueIdentifier: uniqueIdentifier, repositedType: T.repositedType)
            guard let valueTree = currentValueTree, !valueTree.metadata.isDeleted else {
                return
            }
            
            result = T.init(readingFrom: self)
            result?.metadata = valueTree.metadata
        }
        return result
    }
    
    private func transaction(in block: (Void)->Void ) {
        let storedReference = currentTreeReference
        let isDeletion = isDeletionPass
        block()
        isDeletionPass = isDeletion
        currentTreeReference = storedReference
    }
}
