//
//  History.swift
//  Impeller
//
//  Created by Drew McCormack on 22/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

typealias VersionHash=String
typealias DeviceHash=String


struct Version {
    let hash: VersionHash
    let parentHashes: [VersionHash]
    let commitTimestamp: TimeInterval
    let commitRepositoryHash: DeviceHash
}


struct History {
    var currentVersionHash: VersionHash
    var versionsByHash: [VersionHash:Version]
}
