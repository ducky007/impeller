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
    static var repositedType: RepositedType { get }
    
    init(readingFrom repository:PropertyReader)
    mutating func write(in repository:PropertyWriter)
    
    func resolvedValue(forConflictWith newValue:Repositable, context: Any?) -> Self
}


public extension Repositable {
    static var repositedType: RepositedType {
        let baseType = "\(type(of: self))" // Includes .Type
        let type = baseType.characters.split(separator: ".").first!
        return String(type)
    }
    
    func resolvedValue(forConflictWith newValue:Repositable, context: Any? = nil) -> Self {
        return self // Choose the local value by default
    }
    
    func isRepositoryEquivalent(to other:Repositable) -> Bool {
        return valueTree == other.valueTree
    }
    
    var valueTree: ValueTree {
        let builder = ValueTreePlanter(repositable: self)
        return builder.valueTree
    }
}

