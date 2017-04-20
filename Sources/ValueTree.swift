//
//  ValueTree.swift
//  Impeller
//
//  Created by Drew McCormack on 16/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//


public struct ValueTreeIdentity: Equatable, Hashable {
    let uniqueIdentifier: UniqueIdentifier
    let repositedType: RepositedType
    
    public var hashValue: Int {
        return uniqueIdentifier.hash
    }
    
    public static func ==(left: ValueTreeIdentity, right: ValueTreeIdentity) -> Bool {
        return left.uniqueIdentifier == right.uniqueIdentifier && left.repositedType == right.repositedType
    }
}


public struct ValueTreeReference: Equatable, Hashable {
    let identity: ValueTreeIdentity
    let commitIdentifier: CommitIdentifier? // Can be nil if not yet committed to repository
    
    public init(uniqueIdentifier: UniqueIdentifier, repositedType: RepositedType, commitIdentifier: CommitIdentifier?) {
        self.init(identity: ValueTreeIdentity(uniqueIdentifier: uniqueIdentifier, repositedType: repositedType), commitIdentifier: commitIdentifier)
    }
    
    public init(identity: ValueTreeIdentity, commitIdentifier: CommitIdentifier?) {
        self.identity = identity
        self.commitIdentifier = commitIdentifier
    }
    
    public var hashValue: Int {
        return identity.hashValue ^ (commitIdentifier?.hash ?? 0)
    }
    
    public static func ==(left: ValueTreeReference, right: ValueTreeReference) -> Bool {
        return left.identity == right.identity && left.commitIdentifier == right.commitIdentifier
    }
    
    public var asString: String {
        let id = identity
        return "\(id.repositedType)__\(id.uniqueIdentifier)__\(commitIdentifier ?? "Uncommitted")"
    }
}


/// A path to a specific value tree. The reference of the
/// tree itself is last in the list. The root tree is first in the
/// list.
public struct ValueTreePath {
    public let pathFromRoot: [ValueTreeReference]
    
    public var valueTreeReference: ValueTreeReference {
        return pathFromRoot.last!
    }
    
    public var rootReference: ValueTreeReference {
        return pathFromRoot.first!
    }
    
    public var ancestorReferences: [ValueTreeReference] {
        return Array(pathFromRoot.dropLast(1))
    }
    
    public init(pathFromRoot: [ValueTreeReference]) {
        assert(pathFromRoot.count > 0)
        self.pathFromRoot = pathFromRoot
    }
    
    public func appending(_ component: ValueTreeReference) -> ValueTreePath {
        return ValueTreePath(pathFromRoot: pathFromRoot + [component])
    }
}


public struct ValueTree: Equatable, Hashable {
    public var metadata: Metadata
    public var repositedType: RepositedType
    public internal(set) var propertiesByName = [String:Property]()
    
    public var valueTreeReference: ValueTreeReference {
        return ValueTreeReference(uniqueIdentifier: metadata.uniqueIdentifier, repositedType: repositedType, commitIdentifier: metadata.commitIdentifier)
    }
    
    public var propertyNames: [String] {
        return Array(propertiesByName.keys)
    }

    public init(repositedType: RepositedType, metadata: Metadata) {
        self.repositedType = repositedType
        self.metadata = metadata
    }
    
    public func get(_ propertyName: String) -> Property? {
        return propertiesByName[propertyName]
    }
    
    public mutating func set(_ propertyName: String, to property: Property) {
        propertiesByName[propertyName] = property
    }
    
    public mutating func updateChildReferences(with block: (ValueTreeReference)->ValueTreeReference) {
        for (name, property) in propertiesByName {
            switch property {
            case .optionalValueTreeReference(let ref?):
                let newRef = block(ref)
                propertiesByName[name] = .optionalValueTreeReference(newRef)
            case .valueTreeReference(let ref):
                let newRef = block(ref)
                propertiesByName[name] = .valueTreeReference(newRef)
            case .valueTreeReferences(let refs):
                let newRefs = refs.map(block)
                propertiesByName[name] = .valueTreeReferences(newRefs)
            default:
                break
            }
        }
    }
    
    public var childReferences: Set<ValueTreeReference> {
        var references: Set<ValueTreeReference> = []
        for (_, property) in propertiesByName {
            switch property {
            case .optionalValueTreeReference(let ref?), .valueTreeReference(let ref):
                references.insert(ref)
            case .valueTreeReferences(let refs):
                references.formUnion(refs)
            default:
                break
            }
        }
        return references
    }
    
    public var hashValue: Int {
        return metadata.uniqueIdentifier.hash ^ (metadata.commitIdentifier?.hash ?? 0)
    }
    
    public static func ==(left: ValueTree, right: ValueTree) -> Bool {
        return left.repositedType == right.repositedType && left.metadata == right.metadata && left.propertiesByName == right.propertiesByName
    }
    
    func merged(with other: ValueTree?, history: History) -> ValueTree {
        guard let other = other, self != other else {
            return self
        }
        
        var mergedTree: ValueTree!
        let commit = history.fetchCommit(metadata.commitIdentifier ?? "")
        let otherCommit = history.fetchCommit(other.metadata.commitIdentifier ?? "")
        switch (commit, otherCommit) {
        case let (c1?, c2?):
            mergedTree = c1.timestamp < c2.timestamp ? other : self
        case (nil, .some):
            mergedTree = self
        case (.some, nil):
            mergedTree = other
        case (nil, nil):
            mergedTree = self
        }
        
        mergedTree.metadata.isDeleted = metadata.isDeleted || other.metadata.isDeleted
        
        return mergedTree
    }
}

