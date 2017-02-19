//
//  AppDelegate.swift
//  Listless
//
//  Created by Drew McCormack on 07/01/2017.
//  Copyright © 2017 The Mental Faculty B.V. All rights reserved.
//

import UIKit
import Impeller
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    override class func initialize() {
        Log.level = .verbose
    }

    var window: UIWindow?
    var tasksViewController: TasksViewController!
    
    var storeURL: URL {
        let documentsDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return documentsDir.appendingPathComponent("Listless.json")
    }
    
    let localRepository = MonolithicRepository()
    let serializer = JSONForestSerializer()
    let cloudRepository = CloudKitRepository(withUniqueIdentifier: "Main", cloudDatabase: CKContainer.default().privateCloudDatabase)
    lazy var exchange: Exchange = { Exchange(coupling: [self.localRepository, self.cloudRepository], pathForSavedState: nil) }()
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        if FileManager.default.fileExists(atPath: storeURL.path) {
            try? localRepository.load(from: storeURL, with: serializer)
        }
        
        let navController = window!.rootViewController as! UINavigationController
        tasksViewController = navController.topViewController as! TasksViewController
        updateTaskList()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        sync()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        let backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        sync { error in
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        try? localRepository.save(to: storeURL, with: serializer)
    }
    
    @IBAction func sync(_ sender: Any?) {
        sync()
    }
    
    func sync(completionHandler completion: CompletionHandler? = nil) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        exchange.exchange { error in
            if let error = error as? CKError, error.code == .notAuthenticated {
                let alert = UIAlertController(title: "Sign In to iCloud Drive", message: "You need to be signed in to iCloud, and have iCloud Drive active, in order to use Listless. Sign In via the Settings app.", preferredStyle: .alert)
                self.window!.rootViewController!.present(alert, animated: true, completion: nil)
            }
            
            if let error = error {
                print("Error during exchange: \(error)")
            }
            else {
                try! self.localRepository.save(to: self.storeURL, with: self.serializer)
                self.updateTaskList()
            }
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            completion?(error)
        }
    }
    
    func updateTaskList() {
        if let taskList: TaskList = self.localRepository.fetchValue(identifiedBy: "MainList") {
            // Update the task list if it is changed
            if taskList != self.tasksViewController.taskList {
                self.tasksViewController.taskList = taskList
            }
        }
        else {
            // Create a new task list if one doesn't exist
            var newTaskList = TaskList()
            newTaskList.metadata = Metadata(uniqueIdentifier: "MainList")
            self.localRepository.commit(&newTaskList)
            self.tasksViewController.taskList = newTaskList
            
            // Schedule a sync to push this new list to the cloud
            DispatchQueue.main.async { self.sync() }
        }
    }

}

