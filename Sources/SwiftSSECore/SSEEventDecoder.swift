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
    private var hasParsedBOM = false
    
    public init() {}
    
    public func decode(_ chunk: Data) -> [SSEEvent] {
        guard let text = String(data: chunk, encoding: .utf8) else {
            return []
        }
        
        var processedText = text
        
        if !hasParsedBOM {
            hasParsedBOM = true
            if processedText.hasPrefix("\u{FEFF}") {
                processedText.removeFirst()
            }
        }
        
        buffer += processedText
        var events: [SSEEvent] = []
        
        while let line = extractLine() {
            if let event = processLine(line) {
                events.append(event)
            }
        }
        return events
    }
    
    private func extractLine() -> String? {
        var lineEndIndex: String.Index?
        var skipCount = 1
        
        for i in buffer.indices {
            let char = buffer[i]
            if char == "\r" {
                lineEndIndex = i
                let nextIndex = buffer.index(after: i)
                if nextIndex < buffer.endIndex && buffer[nextIndex] == "\n" {
                    skipCount = 2
                }
                break
            } else if char == "\n" {
                lineEndIndex = i
                break
            }
        }
        
        guard let endIndex = lineEndIndex else {
            return nil
        }
        
        let line = String(buffer[..<endIndex])
        let removeEnd = buffer.index(endIndex, offsetBy: skipCount, limitedBy: buffer.endIndex) ?? buffer.endIndex
        buffer.removeSubrange(..<removeEnd)
        
        return line
    }
    
    private func processLine(_ line: String) -> SSEEvent? {
        if line.isEmpty {
            return currentEvent.build()
        }
        
        if line.hasPrefix(":") {
            return nil
        }
        
        if let colonIndex = line.firstIndex(of: ":") {
            let field = String(line[..<colonIndex])
            var value = String(line[line.index(after: colonIndex)...])
            
            if value.hasPrefix(" ") {
                value.removeFirst()
            }
            
            currentEvent.append(field: field, value: value)
        } else {
            currentEvent.append(field: line, value: "")
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
                if !value.contains("\0") {
                    id = value
                }
            case "event":
                event = value
            case "data":
                dataLines.append(value)
            case "retry":
                if let val = Int(value), val >= 0 {
                    retry = val
                }
            default:
                break
            }
        }
        
        mutating func build() -> SSEEvent? {
            guard !dataLines.isEmpty else {
                self = EventBuilder(id: id)
                return nil
            }
            
            let data = dataLines.joined(separator: "\n")
            let event = SSEEvent(id: id, event: event, data: data, retry: retry)
            
            let preservedId = id
            self = EventBuilder(id: preservedId)
            
            return event
        }
        
        init(id: String? = nil) {
            self.id = id
        }
    }
}
