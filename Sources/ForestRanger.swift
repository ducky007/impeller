//
//  ForestRanger.swift
//  Impeller
//
//  Created by Drew McCormack on 05/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

public struct ForestRanger: IteratorProtocol {
    public typealias Element = ValueTreeReference
    
    public let plantedValueTree: PlantedValueTree
    private var visitationList: [ValueTreeReference] = []
    private var index = -1
    
    init(plantedValueTree: PlantedValueTree) {
        self.plantedValueTree = plantedValueTree
        visitationList = visitationList(forTreeAt: plantedValueTree.root)
    }
    
    public mutating func next() -> ValueTreeReference? {
        index += 1
        guard index < visitationList.count else { return nil }
        return visitationList[index]
    }
    
    private func visitationList(forTreeAt reference: ValueTreeReference) -> [ValueTreeReference] {
        guard let valueTree = plantedValueTree.forest.valueTree(at: reference) else { return [] }
        
        var children: [ValueTreeReference] = []
        for (_, property) in valueTree.propertiesByName {
            switch property {
            case .optionalValueTreeReference(let ref?), .valueTreeReference(let ref):
                children.append(ref)
            case .valueTreeReferences(let refs):
                children.append(contentsOf: refs)
            default:
                break
            }
        }
        
        var childDescendents: [ValueTreeReference] = []
        for childRef in children {
            childDescendents.append(contentsOf: visitationList(forTreeAt: childRef))
        }
        
        return [reference] + childDescendents
    }
}
