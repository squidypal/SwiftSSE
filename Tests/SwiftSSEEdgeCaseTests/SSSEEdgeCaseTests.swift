//
//  SSSEEdgeCaseTests.swift
//  SwiftSSE
//
//  Created by squidypal on 2026-01-27.
//

import Testing
@testable import SwiftSSECore
import Foundation

@Suite("SSE Line Ending Tests")
struct SSELineEndingTests {
    @Test("Decode with CRLF endings")
    func testCRLF() {
        let decoder = DefaultSSEEventDecoder()
        let input = "data: hello\r\n\r\n"
        let events = decoder.decode(Data(input.utf8))
        
        #expect(events.count == 1)
        #expect(events[0].data == "hello")
    }
    
    @Test("Decode with CR endings")
    func testCR() {
        let decoder = DefaultSSEEventDecoder()
        let input = "data: hello\r\r"
        let events = decoder.decode(Data(input.utf8))
        
        #expect(events.count == 1)
        #expect(events[0].data == "hello")
    }
    
    @Test("Decode with mixed line endings")
    func testMixedEndings() {
        let decoder = DefaultSSEEventDecoder()
        let input = "id: 1\ndata: line1\r\ndata: line2\r\r"
        let events = decoder.decode(Data(input.utf8))
        
        #expect(events.count == 1)
        #expect(events[0].id == "1")
        #expect(events[0].data == "line1\nline2")
    }
    
    @Test("Encoder normalizes line endings")
    func testEncoderNormalization() {
        let encoder = DefaultSSEEventEncoder()
        let event = SSEEvent(data: "line1\r\nline2\rline3")
        let data = encoder.encode(event)
        let text = String(data: data, encoding: .utf8)
        
        #expect(text == "data: line1\ndata: line2\ndata: line3\n\n")
    }
}

@Suite("SSE ID Persistence Tests")
struct SSEIDPersistenceTests {
    @Test("ID persists across events until changed")
    func testIDPersistence() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        id: 1
        data: first
        
        data: second
        
        id: 2
        data: third
        
        """
        let events = decoder.decode(Data(input.utf8))
        
        #expect(events.count == 3)
        #expect(events[0].id == "1")
        #expect(events[1].id == "1")
        #expect(events[2].id == "2")
    }
    
    @Test("ID with null byte rejected")
    func testIDNullByte() {
        let decoder = DefaultSSEEventDecoder()
        let input = "id: bad\0id\ndata: test\n\n"
        let events = decoder.decode(Data(input.utf8))
        
        #expect(events.count == 1)
        #expect(events[0].id == nil)
    }
}

@Suite("SSE Retry Validation Tests")
struct SSERetryValidationTests {
    @Test("Negative retry ignored")
    func testNegativeRetry() {
        let decoder = DefaultSSEEventDecoder()
        let input = "retry: -1000\ndata: test\n\n"
        let events = decoder.decode(Data(input.utf8))
        
        #expect(events.count == 1)
        #expect(events[0].retry == nil)
    }
    
    @Test("Zero retry accepted")
    func testZeroRetry() {
        let decoder = DefaultSSEEventDecoder()
        let input = "retry: 0\ndata: test\n\n"
        let events = decoder.decode(Data(input.utf8))
        
        #expect(events.count == 1)
        #expect(events[0].retry == 0)
    }
}
