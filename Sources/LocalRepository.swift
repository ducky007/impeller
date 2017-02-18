//
//  Repository.swift
//  Impeller
//
//  Created by Drew McCormack on 08/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

public protocol LocalRepository {
    func fetchValue<T:Repositable>(identifiedBy uniqueIdentifier:UniqueIdentifier) -> T?
    func commit<T:Repositable>(_ value: inout T, resolvingConflictsWith conflictResolver: ConflictResolver)
    func delete<T:Repositable>(_ value: inout T)
}


public protocol PropertyReader: class {
    func read<T:RepositablePrimitive>(_ key:String) -> T?
    func read<T:RepositablePrimitive>(optionalFor key:String) -> T??
    func read<T:RepositablePrimitive>(_ key:String) -> [T]?
    func read<T:Repositable>(_ key:String) -> T?
    func read<T:Repositable>(optionalFor key:String) -> T??
    func read<T:Repositable>(_ key:String) -> [T]?
}


public protocol PropertyWriter: class {
    func write<T:RepositablePrimitive>(_ value:T, for key:String)
    func write<T:RepositablePrimitive>(_ optionalValue:T?, for key:String)
    func write<T:RepositablePrimitive>(_ values:[T], for key:String)
    func write<T:Repositable>(_ value:inout T, for key:String)
    func write<T:Repositable>(_ optionalValue:inout T?, for key:String)
    func write<T:Repositable>(_ values:inout [T], for key:String)
}
