//
//  ValueTree.swift
//  Impeller
//
//  Created by Drew McCormack on 15/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

final class ValueTreeBuilder<T:Repositable> : WriteRepository {
    private (set) var valueTree: ValueTree
    private var repositable: T
    
    init(_ repositable:T) {
        valueTree = ValueTree(typeInRepository: T.typeInRepository, metadata: repositable.metadata)
        self.repositable = repositable
        self.repositable.write(in: self)
    }
    
    func write<T:RepositablePrimitive>(_ value:T, for key:String) {
        let primitive = Primitive(value: value)
        valueTree.set(key, to: .primitive(primitive!))
    }
    
    func write<T:RepositablePrimitive>(_ value:T?, for key:String) {
        let primitive = value != nil ? Primitive(value: value!) : nil
        valueTree.set(key, to: .optionalPrimitive(primitive))
    }
    
    func write<T:RepositablePrimitive>(_ values:[T], for key:String) {
        let primitives = values.map { Primitive(value: $0)! }
        valueTree.set(key, to: .primitives(primitives))
    }
    
    func write<T:Repositable>(_ value:inout T, for key:String) {
        let reference = ValueTreeReference(uniqueIdentifier: value.metadata.uniqueIdentifier, typeInRepository: T.typeInRepository)
        valueTree.set(key, to: .valueTreeReference(reference))
    }
    
    func write<T:Repositable>(_ value:inout T?, for key:String) {
        let id = value?.metadata.uniqueIdentifier
        let reference = id != nil ? ValueTreeReference(uniqueIdentifier: id!, typeInRepository: T.typeInRepository) : nil
        valueTree.set(key, to: .optionalValueTreeReference(reference))
    }
    
    func write<T:Repositable>(_ values:inout [T], for key:String) {
        let references = values.map {
            ValueTreeReference(uniqueIdentifier: $0.metadata.uniqueIdentifier, typeInRepository: T.typeInRepository)
        }
        valueTree.set(key, to: .valueTreeReferences(references))
    }
}

