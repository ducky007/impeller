//
//  Person.swift
//  Impeller
//
//  Created by Drew McCormack on 08/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

import Impeller

struct Person: Repositable {
    
    var metadata = Metadata()
    
    var name = "No Name"
    var age: Int? = nil
    var tags = [String]()
    
    init() {}
    
    init(readingFrom reader:PropertyReader) {
        name = reader.read("name")!
        age = reader.read(optionalFor: "age")!
        tags = reader.read("tags")!
    }
    
    func write(to writer:PropertyWriter) {
        writer.write(name, for: "name")
        writer.write(age, for: "age")
        writer.write(tags, for: "tags")
    }
    
    static func == (left: Person, right: Person) -> Bool {
        return left.name == right.name && left.age == right.age && left.tags == right.tags
    }
}
