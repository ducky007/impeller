//
//  Repositable.swift
//  Impeller
//
//  Created by Drew McCormack on 08/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

public typealias RepositedType = String


public protocol Repositable {
    var metadata: Metadata { get set }
    static var typeInRepository: RepositedType { get }
    
    init?(readingFrom repository:ReadRepository)
    mutating func write(in repository:WriteRepository)
    
    func resolvedValue(forConflictWith newValue:Repositable, context: Any?) -> Self
}


public extension Repositable {
    func resolvedValue(forConflictWith newValue:Repositable, context: Any? = nil) -> Self {
        return self // Choose the local value by default
    }
    
    func isRepositoryEquivalent(to other:Repositable) -> Bool {
        return valueTree == other.valueTree
    }
    
    var valueTree: ValueTree {
        let builder = ValueTreeBuilder(self)
        return builder.valueTree
    }
}

