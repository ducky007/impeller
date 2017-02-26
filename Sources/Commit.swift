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

struct Commit {
    let identifier: CommitIdentifier
    let parentCommitIdentifiers: Set<CommitIdentifier>
    let timestamp: TimeInterval
    let repositoryIdentifier: RepositoryIdentifier
    
    init(identifier: CommitIdentifier = UUID().uuidString, parentCommitIdentifiers: Set<CommitIdentifier>, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate, repositoryIdentifier: RepositoryIdentifier) {
        self.identifier = identifier
        self.parentCommitIdentifiers = parentCommitIdentifiers
        self.timestamp = timestamp
        self.repositoryIdentifier = repositoryIdentifier
    }
}
