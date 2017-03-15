//
//  Commit.swift
//  Impeller
//
//  Created by Drew McCormack on 26/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

public typealias CommitIdentifier=String
public typealias RepositoryIdentifier=String

struct CommitLineage {
    let predecessorIdentifier: CommitIdentifier
    let mergedPredecessorIdentifier: CommitIdentifier?
    
    var predecessors: Set<CommitIdentifier> {
        let merged: [CommitIdentifier] = {
            guard let id = mergedPredecessorIdentifier else { return [] }
            return [id]
        }()
        return Set<CommitIdentifier>(merged + [predecessorIdentifier])
    }
    
    init(predecessor: CommitIdentifier, mergedPredecessor: CommitIdentifier? = nil) {
        self.predecessorIdentifier = predecessor
        self.mergedPredecessorIdentifier = mergedPredecessor
    }
}

public struct Commit {
    let identifier: CommitIdentifier
    let lineage: CommitLineage?
    let timestamp: TimeInterval
    let repositoryIdentifier: RepositoryIdentifier
    
    init(identifier: CommitIdentifier = UUID().uuidString, lineage: CommitLineage?, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate, repositoryIdentifier: RepositoryIdentifier) {
        self.identifier = identifier
        self.lineage = lineage
        self.timestamp = timestamp
        self.repositoryIdentifier = repositoryIdentifier
    }
}
