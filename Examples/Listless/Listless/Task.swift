//
//  Task.swift
//  Listless
//
//  Created by Drew McCormack on 07/01/2017.
//  Copyright © 2017 The Mental Faculty B.V. All rights reserved.
//

import Foundation
import Impeller

struct Task: Repositable, Equatable {
    static var repositedType: RepositedType { return "Task" }
    
    var metadata = Metadata()
    var text = ""
    var tagList = TagList()
    var isComplete = false
    
    init() {}
    
    init(readingFrom reader:PropertyReader) {
        text = reader.read(Key.text.rawValue)!
        tagList = reader.read(Key.tagList.rawValue)!
        isComplete = reader.read(Key.isComplete.rawValue)!
    }
    
    mutating func write(to writer:PropertyWriter) {
        writer.write(text, for: Key.text.rawValue)
        writer.write(&tagList, for: Key.tagList.rawValue)
        writer.write(isComplete, for: Key.isComplete.rawValue)
    }
    
    enum Key: String {
        case text, tagList, isComplete
    }
    
    static func == (left: Task, right: Task) -> Bool {
        return left.text == right.text && left.tagList == right.tagList && left.isComplete == right.isComplete
    }
}
