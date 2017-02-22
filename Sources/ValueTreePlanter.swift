//
//  ValueTree.swift
//  Impeller
//
//  Created by Drew McCormack on 15/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

/// Makes a value tree from a single Repositable
final class ValueTreePlanter<T:Repositable>: PropertyWriter {
    private (set) var valueTree: ValueTree
    private var repositable: T
    weak var forestPlanter: ForestPlanter?
    
    init(repositable:T, forestPlanter: ForestPlanter? = nil) {
        valueTree = ValueTree(repositedType: T.repositedType, metadata: repositable.metadata)
        self.forestPlanter = forestPlanter
        self.repositable = repositable
        self.repositable.write(to: self)
    }
    
    func write<PropertyType:RepositablePrimitive>(_ value:PropertyType, for key:String) {
        let primitive = Primitive(value: value)
        valueTree.set(key, to: .primitive(primitive!))
    }
    
    func write<PropertyType:RepositablePrimitive>(_ value:PropertyType?, for key:String) {
        let primitive = value != nil ? Primitive(value: value!) : nil
        valueTree.set(key, to: .optionalPrimitive(primitive))
    }
    
    func write<PropertyType:RepositablePrimitive>(_ values:[PropertyType], for key:String) {
        let primitives = values.map { Primitive(value: $0)! }
        valueTree.set(key, to: .primitives(primitives))
    }
    
    func write<PropertyType:Repositable>(_ value:inout PropertyType, for key:String) {
        let reference = ValueTreeReference(uniqueIdentifier: value.metadata.uniqueIdentifier, repositedType: PropertyType.repositedType)
        valueTree.set(key, to: .valueTreeReference(reference))
        forestPlanter?.processChild(value)
    }
    
    func write<PropertyType:Repositable>(_ value:inout PropertyType?, for key:String) {
        let id = value?.metadata.uniqueIdentifier
        let reference = id != nil ? ValueTreeReference(uniqueIdentifier: id!, repositedType: PropertyType.repositedType) : nil
        valueTree.set(key, to: .optionalValueTreeReference(reference))
        if let value = value { forestPlanter?.processChild(value) }
    }
    
    func write<PropertyType:Repositable>(_ values:inout [PropertyType], for key:String) {
        let references = values.map {
            ValueTreeReference(uniqueIdentifier: $0.metadata.uniqueIdentifier, repositedType: PropertyType.repositedType)
        }
        valueTree.set(key, to: .valueTreeReferences(references))
        values.forEach { forestPlanter?.processChild($0) }
    }
}

