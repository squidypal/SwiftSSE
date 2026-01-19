//
//  SSEEventDecoder.swift
//  SwiftSSE
//
//  Created by squidypal on 2026-01-19.
//

import Foundation

public protocol SSEEventDecoder {
    func decode(_ chunk: Data) -> [SSEEvent]
}

public final class DefaultSSEEventDecoder: SSEEventDecoder {
    private var buffer = ""
    private var currentEvent = EventBuilder()
    
    public init() {}
    
    public func decode(_ chunk: Data) -> [SSEEvent] {
        guard let text = String(data: chunk, encoding: .utf8) else {
            return[]
        }
        
        buffer += text
        var events: [SSEEvent] = []
        
        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[..<newlineRange.lowerBound])
            buffer.removeSubrange(...newlineRange.lowerBound)
            
            if let event = processLine(line) {
                events.append(event)
            }
        }
        return events
    }
    
    private func processLine(_ line: String) -> SSEEvent? {
        let trimmed = line.description.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            return currentEvent.build()
        }
        
        if trimmed.hasPrefix(":") {
            return nil
        }
        
        if let colonIndex = trimmed.firstIndex(of: ":") {
            let field = String(trimmed[..<colonIndex])
            var value = String(trimmed[trimmed.index(after: colonIndex)...])
            
            if value.hasPrefix(" ") {
                value.removeFirst()
            }
            
            currentEvent.append(field: field, value: value)
        } else {
            currentEvent.append(field: trimmed, value: "")
        }
        
        return nil
    }
    
    
    private struct EventBuilder {
        var id: String?
        var event: String?
        var dataLines: [String] = []
        var retry: Int?
        
        mutating func append(field: String, value: String) {
            switch field {
            case "id":
                id = value
            case "event":
                event = value
            case "data":
                dataLines.append(value)
            case "retry":
                retry = Int(value)
            default:
                break
            }
        }
        
        mutating func build() -> SSEEvent? {
            guard !dataLines.isEmpty else { return nil }
            
            let data = dataLines.joined(separator: "\n")
            let event = SSEEvent(id: id, event: event, data: data, retry: retry)
            
            self = EventBuilder()
            
            return event
        }
    }
}
