//
//  ValueTreeHarvester.swift
//  Impeller
//
//  Created by Drew McCormack on 15/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

/// Makes a Repositable for a single value tree
final class ValueTreeHarvester: PropertyReader {
    
    weak var forestHarvester: ForestHarvester!
    let valueTree: ValueTree
    
    init(valueTree:ValueTree, forestHarvester: ForestHarvester) {
        self.valueTree = valueTree
        self.forestHarvester = forestHarvester
    }
    
    public func harvest<T:Repositable>() -> T {
        var repositable = T(readingFrom: self)
        repositable.metadata = valueTree.metadata
        return repositable
    }
    
    public func read<T:RepositablePrimitive>(_ key:String) -> T? {
        if  let property = valueTree.get(key),
            let primitive = property.asPrimitive() {
            return T(primitive)
        }
        else {
            return nil
        }
    }
    
    public func read<T:RepositablePrimitive>(optionalFor key:String) -> T?? {
        if  let property = valueTree.get(key),
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
        if  let property = valueTree.get(key),
            let primitives = property.asPrimitives() {
            return primitives.flatMap { T($0) }
        }
        else {
            return nil
        }
    }
    
    public func read<T:Repositable>(_ key:String) -> T? {
        if  let property = valueTree.get(key),
            let reference = property.asValueTreeReference() {
            let result:T = forestHarvester.harvestChild(reference)
            return result
        }
        else {
            return nil
        }
    }
    
    public func read<T:Repositable>(optionalFor key:String) -> T?? {
        if  let property = valueTree.get(key),
            let optionalReference = property.asOptionalValueTreeReference(),
            let reference = optionalReference {
            let result:T = forestHarvester.harvestChild(reference)
            return result
        }
        else {
            return nil
        }
    }
    
    public func read<T:Repositable>(_ key:String) -> [T]? {
        if  let property = valueTree.get(key),
            let references = property.asValueTreeReferences() {
            let result: [T] = references.map { self.forestHarvester.harvestChild($0) }
            return result
        }
        else {
            return nil
        }
    }
    
}
