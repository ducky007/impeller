//
//  TimestampCursor.swift
//  Impeller
//
//  Created by Drew McCormack on 05/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

public struct TimestampCursor: Cursor {
    private (set) var timestamp: TimeInterval
    
    public init(timestamp: TimeInterval) {
        self.timestamp = timestamp
    }
    
    public init?(data: Data) {
        timestamp = data.withUnsafeBytes { $0.pointee }
    }
    
    public var data: Data {
        var t = timestamp
        return Data(buffer: UnsafeBufferPointer(start: &t, count: 1))
    }
}
