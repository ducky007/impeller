![Impeller: A Distributed Value Store in Swift](https://cloud.githubusercontent.com/assets/77312/22173713/77d11400-dfcb-11e6-8790-3d39359ed0d7.png)

![Swift Version](https://img.shields.io/badge/Swift-3.0-orange.svg)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Plaforms](https://img.shields.io/badge/Platforms-Linux%20%7C%20macOS%20%7C%20iOS%20%7C%20WatichOS%20%7C%20tvOS-lightgrey.svg)

Introductory Video: [The Value in Trees (from dotSwift 2017)](http://www.thedotpost.com/2017/01/drew-mccormack-the-value-in-trees)

Impeller is a Distributed Value Store (DVS) written in Swift. It was inspired by successful Distributed Version Control Systems (DVCSes) like Git and Mercurial, and appropriates the concept and terminology for use with application data, rather than source code files.

With Impeller, you compose a data model from Swift value types (`struct`s), and persist them locally in a store like SQlite. Values can be _pushed_ to services like CloudKit, and _pulled_ down to other devices, to facilitate sync across devices, and with web apps.

At this juncture, Impeller is largely experimental. It evolves rapidly, and — much like Swift itself — there is no attempt made to sustain backward compatibility. It is not currently recommended for production projects.

## Introduction

### Objectives

Impeller was inspired by the notion that a persistent store, in the vein of Core Data and Realm, could be based on value types, rather than the usual reference types (classes). Additionally, such a store could be designed from day one to work globally, across devices, much like a DVCS such as Git.

Value types like `struct`s and `enum`s play an important role in Swift development, and have a number of advantages over classes for model data. Because they are generally stored in stack memory, they don't incur the cost of allocation and deallocation associated with heap memory. They also do not have to be garbage collected or reference counted, which adds to the performance benefits.

Perhaps even more important than performance, value types offer greater safety guarantees than mutable reference types like objects. Because each value gets copied when passed into a function or assigned to a variable, each value can be treated in isolation, and the risk of race conditions and other concurrency issues is greatly reduced. The ability of a developer to reason about a value is also greatly enhanced when there is a guarantee it will not be modified via an unrelated scope.

While the initial objective for Impeller is to develop a working value store that syncs, the longer term goal is much more ambitious: Impeller should evolve into an abstraction that can push and pull values from a wide variety of backends (_e.g_ CloudKit, SQL databases), and populate arbitrary frontend modelling frameworks (_e.g._ Core Data, Realm). In effect, middleware that couples any supported client framework with any supported cloud service. 

If achieved, this would facilitate much simpler migration between services and frameworks, as well as heterogenous combinations which currently require a large investment of time and effort to realize. For example, imagine an iOS app based on Core Data syncing automatically with Apple's CloudKit, which in turn exchanges data with an Android app utilizing SQlite storage.

### Philosophy

Frameworks like Core Data are mature, and very extensive. To really master such a framework takes years. In return, it gives you an easy way to begin, and takes care of a lot details for you. Caching data, merging conflicts, relationship maintenance, and deletion propagation are all features that help you from day one, and which you can generally forget are operating on your behalf.

But there is a downside to having so much 'magic' in a framework, and you usually encounter that as soon as a project goes beyond the basics. At some point, you realize you don't need the data to be cached, or retain cycles are causing objects to hang around that you would like to be deallocated, or data fetches are scaling badly. The magic that was originally working in your favor is now technical debt, and you start to have to pay it back. You have to learn more and more about how the framework is working internally, often reverse engineering or experimenting to understand private implementation details. The short term gain of not having to know the details demands that you learn those details — and more — in the long term.

This philosophical difference is evident in web frameworks as well. Frameworks like Ruby on Rails took this Core Data approach, making it very easy to step in and get started. But as you came up against performance bottlenecks, you were forced to learn more and more about how the Rails magic was actually working, and — in the long term — this often resulted in even more effort than just doing the hard work upfront.

In contrast, Node.js positions itself at the opposite end of the spectrum. There is as little hidden magic as possible. It is made up of lightweight modules, which you combine to build a web app. You won't get fancy caching unless you explicitly bring in a module to do that for you. In essence, the developer is in charge. Getting started is a little more difficult, but at each step, you understand the technologies you are using, and there is less technical debt as a result.

Our objective with Impeller is that it should fall firmly in the _lightweight_ category with Node.js, contrasting with Core Data and Rails. It should work more like a toolkit that is used to build a modeling layer for your app, rather than a monolithic system. And there should be as little magic as possible. If you need three-way merging for conflict resolution, you can add it, but, in doing so, will be aware of the tradeoffs you are making. If you want in-memory caching, you can add it, and understand the tradeoffs.

## Installation

### Requirements

Impeller is currently only available for iOS. It is a Swift module, requiring Swift 3.

### Carthage

Add Impeller to your _Cartfile_ to have it installed by Carthage.

    github "mentalfaculty/impeller" ~> 0.1

Build using `carthage update`, and drag `Impeller.framework` into Xcode.

### Manual

To install Impeller manually

1. Drag the `Impeller.xcodeproj` into your Xcode project.
2. Select your project's _Target_, and open the _General_ tab.
3. Click the + button in the _Embedded Binaries_ section, and choose `Impeller.framework`.


### Examples

Examples of usage are included in the _Examples_ directory. The _Listless_ project is a good place to begin. It is a simple iPhone task management app which syncs via CloudKit.

Other examples of usage can be found in the various _Tests_ folders.

## Usage

### Making a Model

Unlike most data modelling frameworks (_e.g._ Core Data), Impeller is based on value types (`struct`s). There is no modeling tool, or model file; you simply create your own `struct`s.

#### Repositable Protocol

You need to make your `struct`s conform to the `Repositable` protocol.
```Swift
struct Task: Repositable {
```
The `Repositable` protocol looks like this.
```Swift
public protocol Repositable {
    var metadata: Metadata { get set }
    static var repositedType: RepositedType { get }

    init?(readingFrom reader:PropertyReader)
    mutating func write(to writer:PropertyWriter)
}
```
#### Metadata

Your new type must supply a property for metadata storage.
```Swift
struct Task: Repositable {
    var metadata = Metadata()
```
The `metadata` property is used internally by the framework, and you should generally refrain from modifying it. 

One exception to this rule is the `uniqueIdentifier`, which is a global identifier for your value, and is used to store it and fetch it from repositories (persistent stores and cloud storage). By default, a _UUID_ will be generated for new values, but you can override this and set metadata with a carefully chosen `uniqueIdentifier`. You might do this in order to make shared values that appear on all devices, such as with a global settings struct. Setting a custom `uniqueIdentifer` is analogous to creating a singleton in your app.

#### Properties

The properties of your `struct` can be anything supported by Swift. Properties are not persisted to a repository by default, so you can also include properties that you don't wish to have stored.
```Swift
struct Task: Repositable {
    ...

    var text = ""
    var tagList = TagList()
    var isComplete = false
```
#### Loading Data

You save and load data with Impeller in much the same way you do when using the `NSCoding` protocol included in the `Foundation` framework. You need to implement

1. An initializer which creates a new struct value from data that is loaded from a repository.
2. A function to write the `struct` data into a repository for saving.

The initializer might look like this
```Swift
init?(readingFrom reader:PropertyReader) {
    text = reader.read("text")!
    tagList = reader.read("tagList")!
    isComplete = reader.read("isComplete")!
}
```
The keys passed in are conventionally named the same as your properties, but this is not a necessity. You might find it useful to create an `enum` with `String` raw values to define these keys, rather than using literal values.

#### Which Data Types are Supported?

The `PropertyReader` protocol provides methods to read a variety of data types, including

- Built-in types like `Int`, `Float`, `String`, and `Data`, which are called _primitive types_
- Optional variants of primitive types (_e.g._ `Int?`)
- Arrays of simple built-in types (_e.g._ `[Float]`)
- Other `Repositable` types (_e.g._ `TagList`, where `TagList` is a `struct` conforming to `Repositable`)
- Optional variants of `Repositable` types (_e.g._ `TagList?`)
- Arrays of `Repositable` types (_e.g._ `[TagList]`)

These types are the only ones supported by repositories, but this does not mean your `struct`s cannot include other types. You simply convert to and from these primitive types when storing and loading data, just as you do when using `NSCoding`. For example, if a `struct` includes a `Set`, you would simply convert the `Set` to an `Array` for storage. (It would be wise to sort the `Array`, to prevent unnecessary updates to the repository when the set is unchanged.)

#### Storing Data

The function for storing data into a repository makes use of methods in the `PropertyWriter`.
```Swift
mutating func write(to writer:PropertyWriter) {
    writer.write(text, for: "text")
    writer.write(&tagList, for: "tagList")
    writer.write(isComplete, for: "isComplete")
}
```
This is the inverse of loading data, so the keys used must correspond to the keys used in the initializer above.

### Repositories

Places where data gets stored are referred to as _repositories_, in keeping with the terminology of DVCSes. This also emphasizes the distributed nature of the framework, with repositories spread across devices, and in the cloud. 

#### Creating a Repository

Each repository type has a different setup. Typically, you simply initialize the repository, and store it in an instance variable on a controller object.
```Swift
let localRepository = MonolithicRepository()
```
#### Storing Changes

There is no central managing object in Impeller, like the `NSManagedObjectContext` of Core Data. Instead, when you want to save a `Repositable` type, you simply ask the repository to commit it.
```Swift
localRepository.commit(&task)
```
This commits the whole value, which includes any sub-types in the value tree which descend from `task`.

Note that the `commit` function takes an `inout` parameter, meaning you must pass in a variable, not a constant. The reason for this is that when storing into a repository, the metadata of the stored types (_e.g._ timestamps) get updated to mirror the latest state in the repository. In addition, the value passed in may be merged with data in the store, and thus updated by the commit.

### Exchanges

You can use Impeller as a local store, but most modern apps need to sync data across devices, or with the cloud. You can couple two or more repositories using an _Exchange_.

#### Creating an Exchange

Like the repositories, you usually create an _Exchange_ just after your app launches, and you have created all repositories. You could also do it using a lazy property, like this
```Swift
lazy var exchange: Exchange = { 
    Exchange(coupling: [self.localRepository, self.cloudRepository], pathForSavedState: nil) 
}()
```
#### Exchanging Data

To trigger an exchange of the recent changes between repositories, simply call the `exchange` function.
```Swift
exchange.exchange { error in            
    if let error = error {
        print("Error during exchange: \(error)")
    }
    else {
        // Refresh UI here
    }
}
```
The `exchange` function is asynchronous, with a completion callback, because it typically involves 'slow' network requests.

### Merging

When committing changes to a repository, it is possible that the repository value has been changed by another commit or exchange since the value was originally fetched. It is important to detect this eventuality, so that changes are not overwritten by the stale values in memory. There are plans to offer powerful merging in future, but at the moment only very primitive support is available.

You can implement 
```Swift
func resolvedValue(forConflictWith newValue:Repositable, context: Any?) -> Self
```
from the `Repositable` protocol in your `struct`. By default, this function will do a generic merge, favoring the values in `self`, thus giving the values currently in memory precedence. You can override that behavior to return a different `struct` value, which will be what gets stored in the repository (...and returned from the `commit` function).

### Gotchas

A value store is quite a different beast to a store based on reference types (_e.g._ Core Data). Some aspects become more straightforward when using values (_e.g._ passing values between threads), but other behaviors may surprise you at first. This section covers a few of the more major differences.

#### Advantages of Value Types

In addition to the unexpected behaviors that come with using value types, there are a number of welcome surprises. Here are a few of the advantages of using a value store:

- Value types are often stored on the stack, and don't incur the cost of heap allocation and deallocation.
- There is no need for reference counting or garbage collection, making creation and cleanup much faster.
- Value types are copied when assigned or passed to a function, making data contention much less likely.
- Value types can be passed between threads with little risk, because each thread gets a separate copy.
- There is no need to define complex deletion rules. Deletion is handled naturally by the ownership hierarchy of the `struct`s.
- Keeping a history of changes is as simple as keeping an array of root values. This is very useful for features such as undo.

#### Uniquing

Uniquing is a feature of class-based frameworks like Core Data. It ensures that when you fetch from a store, you do not end up with two objects representing the same stored entity. The framework checks first if an object already exists in memory for the data in question, and returns that whenever you attempt to fetch that data entity again.

In a value store, uniquing would make no sense, because every value gets copied numerous times. Creating a copy is as simple as assigning to a variable, or passing it to a function.

At first, this may seem problematic to a seasoned Core Data developer, but it just requires a minor shift in expectations. When working with Impeller, you have to recognize that the copy of the value you are working with is not unique, that there may be other values representing the same stored entity, and that they may all be in different states. A value is temporal, and only influences other values when it is committed to a repository.

#### Relationship Cycles

When you develop a data model from `struct`s, you form _value trees_. A `struct` can contain other `struct`s, and the entirety forms a tree in memory. 

Frameworks like Core Data are based around related entities, which can create arbitrary graphs. This is flexible, but has some downsides. For example, Core Data models form retain cycles which lead to memory leaks unless active steps are taken to break them (_e.g._ resetting the context).

As mentioned early, `struct`s are stack types, and do not have any issues with retain cycles. They are cleaned up automatically when exiting a scope. The price paid for this is that Impeller cannot be used to directly model arbitrary graphs of data.

With Impeller, you build your model out of one or more value trees, but if you need relationships between trees, you can mimic them using so-called _weak relationships_. A weak relationship simply involves storing the `uniqueIdentifier` of another object in a property. When you need to use the related object, you just fetch it from the store.

While it is not possible to create cyclic graphs of related values, you can use weak relationships to achieve very similar behavior. In this respect, using Impeller need not be so different to other frameworks, and the relationship cycles — where they exist — should be much more evident.

#### Copying Sub-Values

Repositable `struct`s can contain other repositable values, forming a tree, but there is nothing to stop you from copying a sub-value into a different variable. For example
```Swift
struct Child: Repositable {
    ...
}

struct Person: Repositable {
    ...
    var child: Child
}

var dave = Person()
var child = dave.child
child.name = "Tom"
repository.commit(&child)
```
In this code, the `Child` of the value `dave` gets copied into a separate variable, altered, and then committed. It is important to realize that — as far as the repository is concerned — this is the same as changing the `child` property of `dave` directly and committing that. The two copies of the `Child` have the same `uniqueIdentifier`, and represent the same data in the repository. 

If the intention was to make a new, independent child, it would be necessary to reset the metadata, like this
```Swift
var dave = Person()
var child = dave.child
child.metadata = Metadata()
child.name = "Tom"
repository.commit(&child)
```
This code would create a whole new `Child` value in the repository, which would be unrelated to the original `Person`.

#### Trees with Variable Depth

In theory you can create trees of variable depth using `struct`s and `protocol`s. For example, it would be possible to create an `AnyRepositable` `struct` that forwards all function calls to a wrapped value of a concrete `Repositable` type. 

At this point, it is unclear if Impeller can be made to work with such types. It is an area of investigation.

## Progress

### State of the Union

The project is still in a very early stage, and not much more than a concept prototype. The following features are in place:

- In-memory repository
- CloudKit repository
- Exchange
- Single timestamp for each `Repositable` value. Used in exchanging.

### Imminent Projects

There are many plans for improving on this. Here are some of the projects that have a high priority. If you would like to contribute, fork the project, and issue pull requests, or get involved in issue discussion.

- Atomic persistence of in-memory repository (_e.g._ JSON, Property List)
- SQLite repository
- Timestamps for individual properties, for more granular merging
- Option to use three-way merging, with originally fetched value, newly fetched value, and in-memory value
- Decoupling of Impeller `Repositable` types, and the underlying value trees, to facilitate other front-ends (_e.g._ Core Data)
