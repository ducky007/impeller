//
//  Tags.swift
//  Listless
//
//  Created by Drew McCormack on 07/01/2017.
//  Copyright © 2017 The Mental Faculty B.V. All rights reserved.
//

import Foundation
import Impeller

struct TagList: Repositable, Equatable {
    static var repositedType: RepositedType { return "TagList" }
    
    var metadata = Metadata()
    var tags: [String] = []
    var asString: String {
        return tags.joined(separator: " ")
    }
    
    init() {}
    
    init(fromText text:String) {
        let newTags = text.characters.split { $0 == " " }.map { String($0) }.filter { $0.characters.count > 0 }
        tags = Array(Set(newTags)).sorted()
    }
    
    init(readingFrom repository:PropertyReader) {
        tags = repository.read(Key.tags.rawValue)!
    }
    
    mutating func write(in repository:PropertyWriter) {
        repository.write(tags, for: Key.tags.rawValue)
    }
    
    enum Key: String {
        case tags
    }
    
    static func ==(left: TagList, right: TagList) -> Bool {
        return left.tags == right.tags
    }
}
