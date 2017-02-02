//
//  Created by Drew McCormack on 12/09/16.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

import Foundation

/// The shared Logger instance.
/// To log, simply use calls like
///
///    Log.error("Message")
///
public let Log = Logger()

/// Class that handles logging. Generally you use the shared instance Log.
public final class Logger {
    
    /// Supported log levels.
    public enum Level : Int, Comparable {
        case none       /// No logging
        case info       /// Important info that should nearly always be logged.
        case error      /// Serious error occurred
        case warning    /// Warning of potentially problematic situation
        case trace      /// Path through code. Usually one per function.
        case verbose    /// All messages.
        
        var stringValue: String {
            switch self {
            case .none:
                return "N"
            case .info:
                return "I"
            case .error:
                return "E"
            case .warning:
                return "W"
            case .trace:
                return "T"
            case .verbose:
                return "V"
            }
        }
    }
    
    /// Current logging level. Logging a message at or below this level will
    /// result in output. Default is .none
    public var level = Level.none
    
    // The following functions include a number of performance enhancements.
    // The class is final, so that the compiler can inline them. (It cannot
    // inline a dynamically dispatched function.)
    // Also, an @autoclosure is used instead of a String argument for the message.
    // The reason for this is to avoid the expense of generating a string that
    // may not be used (perhaps with expensive string interpolation). Using a closure,
    // we postpone the execution of the string generation until we are sure
    // we need to print out the message.
    
    /// Log a message at verbose level.
    public func verbose(_ messageClosure: @autoclosure () -> String, path: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        if level >= .verbose {
            Logger.log(messageClosure, level: .verbose, path: path, function: function, line: line)
        }
    }
    
    /// Log a message at trace level.
    public func trace(_ messageClosure: @autoclosure () -> String, path: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        if level >= .trace {
            Logger.log(messageClosure, level: .trace, path: path, function: function, line: line)
        }
    }
    
    /// Log a message at warning level.
    public func warning(_ messageClosure: @autoclosure () -> String, path: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        if level >= .warning {
            Logger.log(messageClosure, level: .warning, path: path, function: function, line: line)
        }
    }
    
    /// Log a message at error level.
    public func error(_ messageClosure: @autoclosure () -> String, path: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        if level >= .error {
            Logger.log(messageClosure, level: .error, path: path, function: function, line: line)
        }
    }
    
    /// Log a message at info level.
    public func info(_ messageClosure: @autoclosure () -> String, path: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        if level >= .error {
            Logger.log(messageClosure, level: .info, path: path, function: function, line: line)
        }
    }
    
    /// Prints out a log message, with no log level checks.
    fileprivate class func log(_ messageClosure: @autoclosure () -> String, level: Level, path: StaticString, function: StaticString, line: Int = #line) {
        let filename = (String(describing: path) as NSString).lastPathComponent
        print("\(level.stringValue) \(filename)(\(line)) : \(function) : \(messageClosure())")
    }
}

public func <(a: Logger.Level, b: Logger.Level) -> Bool {
    return a.rawValue < b.rawValue
}
