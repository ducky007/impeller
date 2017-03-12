//
//  ForestRanger.swift
//  Impeller
//
//  Created by Drew McCormack on 05/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

public struct ForestRanger: IteratorProtocol {
    public typealias Element = ValueTreePath
    
    public let plantedValueTree: PlantedValueTree
    
    private var visitationList: [ValueTreePath] = []
    private var index = -1
    
    init(plantedValueTree: PlantedValueTree) {
        self.plantedValueTree = plantedValueTree
        
        let rootPath = ValueTreePath(pathFromRoot: [plantedValueTree.root])
        visitationList = visitationList(forTreeAt: rootPath)
    }
    
    public mutating func next() -> ValueTreePath? {
        index += 1
        guard index < visitationList.count else { return nil }
        return visitationList[index]
    }
    
    private func visitationList(forTreeAt path: ValueTreePath) -> [ValueTreePath] {
        guard let treeRef = path.pathFromRoot.last, let valueTree = plantedValueTree.forest.valueTree(at: treeRef) else { return [] }
        
        let childRefs = valueTree.childReferences
        var childDescendentPaths: [ValueTreePath] = []
        for childRef in childRefs {
            let childPath = path.appending(childRef)
            childDescendentPaths.append(contentsOf: visitationList(forTreeAt: childPath))
        }
        
        return [path] + childDescendentPaths
    }
}
