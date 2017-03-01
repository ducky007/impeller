//
//  ValueTree.swift
//  Impeller
//
//  Created by Drew McCormack on 16/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//


public struct ValueTreeReference: Equatable, Hashable {
    let uniqueIdentifier: UniqueIdentifier
    let repositedType: RepositedType
    let commitIdentifier: CommitIdentifier?
    
    public init(uniqueIdentifier: UniqueIdentifier, repositedType: RepositedType, commitIdentifier: CommitIdentifier? = nil) {
        self.uniqueIdentifier = uniqueIdentifier
        self.repositedType = repositedType
        self.commitIdentifier = commitIdentifier
    }
    
    public var hashValue: Int {
        return uniqueIdentifier.hash ^ (commitIdentifier?.hash ?? 0)
    }
    
    public static func ==(left: ValueTreeReference, right: ValueTreeReference) -> Bool {
        return left.uniqueIdentifier == right.uniqueIdentifier && left.repositedType == right.repositedType && left.commitIdentifier == right.commitIdentifier
    }
    
    public var asString: String {
        return "\(repositedType)__\(uniqueIdentifier)__\(commitIdentifier)"
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

