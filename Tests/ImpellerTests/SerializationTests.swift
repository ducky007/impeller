//
//  SerializationTests.swift
//  Impeller
//
//  Created by Drew McCormack on 31/01/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import XCTest
import Impeller

class SerializationTests: XCTestCase {
    
    var repository: MonolithicRepository!
    let dirURL = FileManager.default.temporaryDirectory.appendingPathComponent("SerializationTests")
    var storeURL: URL!
    
    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(at: dirURL)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: false, attributes: nil)
        storeURL = dirURL.appendingPathComponent("store.db")
        repository = MonolithicRepository()
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: dirURL)
        super.tearDown()
    }
    
    func testFileIsCreated() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        try repository.saveJSON(to: storeURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }
    
    func testSaveAndLoad() throws {
        var person = Person()
        person.name = "Bob"
        repository.commit(&person)
        try repository.saveJSON(to: storeURL)
        try repository = MonolithicRepository(withJSONAt: storeURL)
        let fetchedPerson: Person? = repository.fetchValue(identifiedBy: person.metadata.uniqueIdentifier)
        XCTAssertEqual(fetchedPerson!.name, "Bob")
    }
    
    func testNestedTypes() throws {
        var parent = Parent()
        var child = Child()
        child.age = 14
        parent.child = child
        
        repository.commit(&parent)
        
        try repository.saveJSON(to: storeURL)
        try repository = MonolithicRepository(withJSONAt: storeURL)
        
        let fetchedParent: Parent? = repository.fetchValue(identifiedBy: parent.metadata.uniqueIdentifier)
        XCTAssertEqual(fetchedParent!.child.age, 14)
    }
}
