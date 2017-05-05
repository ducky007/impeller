//
//  PlantedValueTree.swift
//  Impeller
//
//  Created by Drew McCormack on 07/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

public struct PlantedValueTree: Sequence {
    
    public let forest: Forest
    public let root: ValueTreeReference
    
    public func makeIterator() -> ForestRanger {
        return ForestRanger(plantedValueTree: self)
    }
    
    public func map(with block: (ValueTree) -> ValueTree) -> PlantedValueTree {
        var tempForest = Forest()
        for path in self {
            let originalTree = forest.valueTree(at: path.valueTreeReference)!
            let newTree = block(originalTree)
            tempForest.update(newTree)
        }
        return PlantedValueTree(forest: tempForest, root: root)
    }
}
