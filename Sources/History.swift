//
//  History.swift
//  Impeller
//
//  Created by Drew McCormack on 22/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

struct History {
    let repositoryIdentifier: RepositoryIdentifier
    private var commitsByIdentifier: [CommitIdentifier:Commit] = [:]
    private (set) var heads: Set<CommitIdentifier> = []
    
    var repositoryHead: CommitIdentifier? {
        return heads.filter({ commitsByIdentifier[$0]?.repositoryIdentifier == repositoryIdentifier }).first
    }
    
    var otherRepositoryHeads: Set<CommitIdentifier> {
        guard  let repositoryHead = repositoryHead else { return heads }
        return heads.subtracting([repositoryHead])
    }
    
    init(repositoryIdentifier: RepositoryIdentifier) {
        self.repositoryIdentifier = repositoryIdentifier
    }
    
    func commit(with identifier: CommitIdentifier) -> Commit? {
        return commitsByIdentifier[identifier]
    }
    
    mutating func add(_ commit: Commit) {
        precondition(commitsByIdentifier[commit.identifier] == nil)
        commitsByIdentifier[commit.identifier] = commit
    }
    
    @discardableResult mutating func commitNewHead() -> Commit {
        let parents: Set<CommitIdentifier> = repositoryHead != nil ? [repositoryHead!] : []
        let newCommit = Commit(parentCommitIdentifiers: parents, repositoryIdentifier: repositoryIdentifier)
        add(newCommit)
        heads.subtract(parents)
        heads.insert(newCommit.identifier)
        return newCommit
    }
 
    @discardableResult mutating func mergeHead(with otherHeads: Set<CommitIdentifier>) -> Commit {
        precondition(otherHeads.isSubset(of: otherRepositoryHeads))
        let allParents: Set<CommitIdentifier> = {
            var result = otherHeads
            if let repositoryHead = repositoryHead { result.insert(repositoryHead) }
            return result
        }()
        let newCommit = Commit(parentCommitIdentifiers: allParents, repositoryIdentifier: repositoryIdentifier)
        add(newCommit)
        allParents.forEach { heads.remove($0) }
        heads.insert(newCommit.identifier)
        return newCommit
    }
}
