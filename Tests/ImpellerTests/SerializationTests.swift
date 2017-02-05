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
    var serializer: JSONForestSerializer!
    let dirURL = FileManager.default.temporaryDirectory.appendingPathComponent("SerializationTests")
    var storeURL: URL!
    
    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: false, attributes: nil)
        storeURL = dirURL.appendingPathComponent("store.db")
        repository = MonolithicRepository()
        serializer = JSONForestSerializer()
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: dirURL)
        super.tearDown()
    }
    
    func testFileIsCreated() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        try repository.save(to: storeURL, with: serializer)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }
    
    func testSaveAndLoad() throws {
        var person = Person()
        person.name = "Bob"
        repository.commit(&person)
        try repository.save(to: storeURL, with: serializer)
        try repository.load(from: storeURL, with: serializer)
        let fetchedPerson: Person? = repository.fetchValue(identifiedBy: person.metadata.uniqueIdentifier)
        XCTAssertEqual(fetchedPerson!.name, "Bob")
    }
    
    func testNestedTypes() throws {
        var parent = Parent()
        var child = Child()
        child.age = 14
        parent.child = child
        
        repository.commit(&parent)
        
        try repository.save(to: storeURL, with: serializer)
        try repository.load(from: storeURL, with: serializer)
        
        let fetchedParent: Parent? = repository.fetchValue(identifiedBy: parent.metadata.uniqueIdentifier)
        XCTAssertEqual(fetchedParent!.child.age, 14)
    }
}
