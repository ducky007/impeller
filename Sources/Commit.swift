//
//  Commit.swift
//  Impeller
//
//  Created by Drew McCormack on 26/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

typealias CommitIdentifier=String
typealias RepositoryIdentifier=String

struct CommitParentage {
    let parent: CommitIdentifier
    let otherParent: CommitIdentifier?
    var parentIdentifiers: [CommitIdentifier] {
        return [parent] + (otherParent != nil ? [otherParent!] : [])
    }
    
    init(parent: CommitIdentifier, otherParent: CommitIdentifier? = nil) {
        self.parent = parent
        self.otherParent = otherParent
    }
}

struct Commit {
    let identifier: CommitIdentifier
    let parentage: CommitParentage?
    let timestamp: TimeInterval
    let repositoryIdentifier: RepositoryIdentifier
    
    init(identifier: CommitIdentifier = UUID().uuidString, parentage: CommitParentage?, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate, repositoryIdentifier: RepositoryIdentifier) {
        self.identifier = identifier
        self.parentage = parentage
        self.timestamp = timestamp
        self.repositoryIdentifier = repositoryIdentifier
    }
}
