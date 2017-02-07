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
    
}
