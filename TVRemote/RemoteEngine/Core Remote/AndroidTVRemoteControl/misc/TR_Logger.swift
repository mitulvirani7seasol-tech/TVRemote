//
//  TR_Logger.swift
//  
//
//

import Foundation

public protocol TR_Logger {
    func debugLog(_ str: String)
    
    func infoLog(_ str: String)
    
    func errorLog(_ str: String)
}

public class TR_DefaultLogger: TR_Logger {
    public init() {}
    
    public func debugLog(_ str: String) {
        log("Debug: " + str)
    }
    
    public func infoLog(_ str: String) {
        log("Info: " + str)
    }
    
    public func errorLog(_ str: String) {
        log("Error: " + str)
    }
    
    private func log(_ str: String) {
        NSLog(str)
    }
}
