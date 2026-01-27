//
//  SSEEventEncoder.swift
//  SwiftSSE
//
//  Created by squidypal on 2026-01-19.
//

import Foundation

public protocol SSEEventEncoder {
    func encode(_ event: SSEEvent) -> Data
}

public struct DefaultSSEEventEncoder: SSEEventEncoder {
    public init() {}
    
    public func encode(_ event: SSEEvent) -> Data {
        var result = ""
        
        if let id = event.id {
            result += "id: \(id)\n"
        }
        
        if let eventType = event.event {
            result += "event: \(eventType)\n"
        }
        
        if let retry = event.retry {
            result += "retry: \(retry)\n"
        }
        
        let normalized = event.data
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            result += "data: \(line)\n"
        }
        
        result += "\n"
        
        return Data(result.utf8)
    }
}
