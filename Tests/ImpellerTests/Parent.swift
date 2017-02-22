//
//  Parent.swift
//  Impeller
//
//  Created by Drew McCormack on 08/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

import Impeller

struct Parent: Repositable {
    
    var metadata = Metadata()
    
    var child = Child()
    var children = [Child]()

    init() {}
    
    init(readingFrom reader:PropertyReader) {
        child = reader.read("child")!
        children = reader.read("children")!
    }
    
    mutating func write(to writer:PropertyWriter) {
        writer.write(&child, for: "child")
        writer.write(&children, for: "children")
    }
}
