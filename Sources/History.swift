//
//  History.swift
//  Impeller
//
//  Created by Drew McCormack on 22/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

enum HistoryError: Error {
    case mergeError(reason: String)
}

struct History {
    let repositoryIdentifier: RepositoryIdentifier
    private var commitsByIdentifier: [CommitIdentifier:Commit] = [:]
    private (set) var head: CommitIdentifier?                   // Current local head
    private (set) var detachedHeads: Set<CommitIdentifier> = [] // Local heads branched from past
    private (set) var remoteHeads: Set<CommitIdentifier> = []   // Heads created remotely
    
    init(repositoryIdentifier: RepositoryIdentifier) {
        self.repositoryIdentifier = repositoryIdentifier
    }
    
    func fetchCommit(_ identifier: CommitIdentifier) -> Commit? {
        return commitsByIdentifier[identifier]
    }
    
    private mutating func add(_ commit: Commit) {
        precondition(commitsByIdentifier[commit.identifier] == nil)
        commitsByIdentifier[commit.identifier] = commit
    }
    
    @discardableResult mutating func commitHead(basedOn predecessorIdentifier: CommitIdentifier?) -> Commit {
        let predecessorToUse = predecessorIdentifier ?? head
        let lineage = predecessorToUse != nil ? CommitLineage(predecessor: predecessorToUse!) : nil
        let newCommit = Commit(lineage: lineage, repositoryIdentifier: repositoryIdentifier)
        add(newCommit)
        
        if let predecessorToUse = predecessorToUse {
            if predecessorToUse == head {
                // Fast forward existing head
                head = newCommit.identifier
            }
            else if detachedHeads.contains(predecessorToUse) {
                // Extend a detached head
                detachedHeads.remove(predecessorToUse)
                detachedHeads.insert(newCommit.identifier)
            }
            else {
                // Add a new detached head
                detachedHeads.insert(newCommit.identifier)
            }
        }
        else {
            // First commit
            assert(head == nil)
            head = newCommit.identifier
        }

        return newCommit
    }
 
    @discardableResult mutating func merge(_ otherHead: CommitIdentifier) throws -> Commit {
        guard let head = head else {
            throw HistoryError.mergeError(reason: "No local head in repo")
        }
        guard detachedHeads.contains(otherHead) || remoteHeads.contains(otherHead) else {
            throw HistoryError.mergeError(reason: "Merge head is not in repository heads list")
        }
        
        let lineage = CommitLineage(predecessor: head, mergedPredecessor: otherHead)
        let newCommit = Commit(lineage: lineage, repositoryIdentifier: repositoryIdentifier)
        add(newCommit)
        
        remoteHeads.remove(otherHead)
        detachedHeads.remove(otherHead)
        self.head = newCommit.identifier

        return newCommit
    }
    
    func greatestCommonAncestor(ofCommitsIdentifiedBy commitIdentifiers: (CommitIdentifier, CommitIdentifier)) -> CommitIdentifier? {
        // Find all ancestors of first commit. Determine how many generations back each commit is.
        // We take the shortest path to any given commit, ie, the minimum of possible paths.
        var generationById = [CommitIdentifier:Int]()
        var front: Set<CommitIdentifier> = [commitIdentifiers.0]
        
        func propagateFront() {
            var newFront = Set<CommitIdentifier>()
            for predecessor in front {
                let commit = self.fetchCommit(predecessor)!
                newFront.formUnion(commit.lineage?.predecessors ?? [])
            }
            front = newFront
        }
        
        var generation = 0
        while front.count > 0 {
            front.forEach { generationById[$0] = min(generationById[$0] ?? Int.max, generation) }
            propagateFront()
            generation += 1
        }
        
        // Now go through ancestors of second until we find the first in common with the first ancestors
        front = [commitIdentifiers.1]
        let ancestorsOfFirst = Set(generationById.keys)
        while front.count > 0 {
            let common = ancestorsOfFirst.intersection(front)
            let sorted = common.sorted { generationById[$0]! < generationById[$1]! }
            if let mostRecentCommon = sorted.first { return mostRecentCommon }
            propagateFront()
        }
        
        return nil
    }
    
    /// Block returns true to continue the visits, and false to terminate
    func visitPredecessors(ofCommitIdentifiedBy commitIdentifier: CommitIdentifier, executing block: (Commit)->Bool ) {
        let _ = performVisitPredecessors(ofCommitIdentifiedBy: commitIdentifier, executing: block)
    }
    
    private func performVisitPredecessors(ofCommitIdentifiedBy commitIdentifier: CommitIdentifier, executing block: (Commit)->Bool ) -> Bool {
        guard let commit = commitsByIdentifier[commitIdentifier] else { return true }
        guard block(commit) else { return false }
        guard let lineage = commit.lineage else { return true }
        guard performVisitPredecessors(ofCommitIdentifiedBy: lineage.predecessorIdentifier, executing:  block) else { return false }
        guard let predecessor = lineage.mergedPredecessorIdentifier else { return true }
        guard performVisitPredecessors(ofCommitIdentifiedBy: predecessor, executing:  block) else { return false }
        return true
    }
}
