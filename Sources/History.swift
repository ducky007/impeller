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
    private (set) var head: CommitIdentifier?                   // Current local head
    private (set) var detachedHeads: Set<CommitIdentifier> = [] // Local heads branched from past
    private (set) var remoteHeads: Set<CommitIdentifier> = []   // Heads created remotely
    
    init(repositoryIdentifier: RepositoryIdentifier) {
        self.repositoryIdentifier = repositoryIdentifier
    }
    
    func fetchCommit(_ identifier: CommitIdentifier) -> Commit? {
        return commitsByIdentifier[identifier]
    }
    
    mutating func add(_ commit: Commit) {
        precondition(commitsByIdentifier[commit.identifier] == nil)
        commitsByIdentifier[commit.identifier] = commit
    }
    
    @discardableResult mutating func commitNewHead(basedOn parentIdentifier: CommitIdentifier?) -> Commit {
        let lineage = parentIdentifier != nil ? CommitLineage(parent: parentIdentifier!) : nil
        let newCommit = Commit(lineage: lineage, repositoryIdentifier: repositoryIdentifier)
        add(newCommit)
        
        if let parentIdentifier = parentIdentifier {
            if parentIdentifier == head {
                // Fast forward existing head
                head = parentIdentifier
            }
            else if detachedHeads.contains(parentIdentifier) {
                // Extend a detached head
                detachedHeads.remove(parentIdentifier)
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
 
    @discardableResult mutating func merge(_ otherHead: CommitIdentifier) -> Commit {
        precondition(otherRepositoryHeads.contains(otherHead))
        let parentage = CommitParentage(parent: otherHead, otherParent: repositoryHead)
        let newCommit = Commit(parentage: parentage, repositoryIdentifier: repositoryIdentifier)
        add(newCommit)
        parentage.parentIdentifiers.forEach { heads.remove($0) }
        heads.insert(newCommit.identifier)
        return newCommit
    }
    
    func greatestCommonAncestor(ofCommitsIdentifiedBy commitIdentifiers: (CommitIdentifier, CommitIdentifier)) -> CommitIdentifier? {
        // Find all ancestors of first commit. Determine how many generations back each commit is.
        // We take the shortest path to any given commit, ie, the minimum of possible paths.
        var generationById = [CommitIdentifier:Int]()
        var frontline: Set<CommitIdentifier> = [commitIdentifiers.0]
        var generation = 0
        while frontline.count > 0 {
            frontline.forEach { generationById[$0] = min(generationById[$0] ?? Int.max, generation) }
            
            // Update frontline by going back a generation for each commit
            var newFrontLine = Set<CommitIdentifier>()
            for ancestorIdentifier in frontline {
                let commit = self.fetchCommit(ancestorIdentifier)!
                newFrontLine.formUnion(commit.parentage?.parentIdentifiers ?? [])
            }
            frontline = newFrontLine
            
            // Increment generation
            generation += 1
        }
        
        // Now go through ancestors of second until we find the first in common with the first ancestors
        frontline = [commitIdentifiers.1]
        let ancestorsOfFirst = Set(generationById.keys)
        while frontline.count > 0 {
            let common = ancestorsOfFirst.intersection(frontline)
            let sorted = common.sorted { generationById[$0]! < generationById[$1]! }
            if let mostRecentCommon = sorted.first { return mostRecentCommon }
            
            // Move back a generation
            var newFrontLine = Set<CommitIdentifier>()
            for ancestorIdentifier in frontline {
                let commit = self.fetchCommit(ancestorIdentifier)!
                newFrontLine.formUnion(commit.parentage?.parentIdentifiers ?? [])
            }
            frontline = newFrontLine
        }
        
        return nil
    }
}
