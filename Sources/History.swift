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
    
    func fetchCommit(_ identifier: CommitIdentifier) -> Commit? {
        return commitsByIdentifier[identifier]
    }
    
    mutating func add(_ commit: Commit) {
        precondition(commitsByIdentifier[commit.identifier] == nil)
        commitsByIdentifier[commit.identifier] = commit
    }
    
    @discardableResult mutating func commitNewHead() -> Commit {
        let parentage = repositoryHead != nil ? CommitParentage(parent: repositoryHead!) : nil
        let newCommit = Commit(parentage: parentage, repositoryIdentifier: repositoryIdentifier)
        add(newCommit)
        if let parentage = parentage { heads.subtract(parentage.parentIdentifiers) }
        heads.insert(newCommit.identifier)
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
                let commit = self.commit(with: ancestorIdentifier)!
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
                let commit = self.commit(with: ancestorIdentifier)!
                newFrontLine.formUnion(commit.parentage?.parentIdentifiers ?? [])
            }
            frontline = newFrontLine
        }
        
        return nil
    }
}
