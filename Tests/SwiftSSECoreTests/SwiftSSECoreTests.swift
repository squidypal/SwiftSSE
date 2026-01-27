//
//  SwiftSSECoreTests.swift
//  SwiftSSE
//
//  Created by squidypal on 2026-01-27.
//

import Testing
@testable import SwiftSSECore
import Foundation

@Suite("SSEEvent Tests")
struct SSEEventTests {
    @Test("Event initialization")
    func testEventInit() {
        let event = SSEEvent(id: "123", event: "message", data: "test", retry: 5000)
        #expect(event.id == "123")
        #expect(event.event == "message")
        #expect(event.data == "test")
        #expect(event.retry == 5000)
    }
    
    @Test("Event JSON decoding")
    func testEventJSONDecoding() throws {
        struct TestPayload: Codable, Equatable {
            let name: String
            let value: Int
        }
        
        let json = #"{"name":"test","value":42}"#
        let event = SSEEvent(data: json)
        
        let decoded = try event.decode(TestPayload.self)
        #expect(decoded == TestPayload(name: "test", value: 42))
    }
}

@Suite("SSEEventEncoder Tests")
struct SSEEventEncoderTests {
    let encoder = DefaultSSEEventEncoder()
    
    @Test("Encode simple event")
    func testSimpleEvent() {
        let event = SSEEvent(data: "hello")
        let data = encoder.encode(event)
        let text = String(data: data, encoding: .utf8)
        
        #expect(text == "data: hello\n\n")
    }
    
    @Test("Encode event with all fields")
    func testFullEvent() {
        let event = SSEEvent(id: "42", event: "message", data: "test", retry: 3000)
        let data = encoder.encode(event)
        let text = String(data: data, encoding: .utf8)
        
        #expect(text == "id: 42\nevent: message\nretry: 3000\ndata: test\n\n")
    }
    
    @Test("Encode multiline data")
    func testMultilineData() {
        let event = SSEEvent(data: "line1\nline2\nline3")
        let data = encoder.encode(event)
        let text = String(data: data, encoding: .utf8)
        
        #expect(text == "data: line1\ndata: line2\ndata: line3\n\n")
    }
    
    @Test("Encode event with empty lines")
    func testEmptyLines() {
        let event = SSEEvent(data: "first\n\nlast")
        let data = encoder.encode(event)
        let text = String(data: data, encoding: .utf8)
        
        #expect(text == "data: first\ndata: \ndata: last\n\n")
    }
}

@Suite("SSEEventDecoder Tests")
struct SSEEventDecoderTests {
    @Test("Decode simple event")
    func testSimpleEvent() {
        let decoder = DefaultSSEEventDecoder()
        let data = Data("data: hello\n\n".utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].data == "hello")
        #expect(events[0].id == nil)
        #expect(events[0].event == nil)
    }
    
    @Test("Decode event with all fields")
    func testFullEvent() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        id: 123
        event: update
        retry: 5000
        data: test data
        
        """
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].id == "123")
        #expect(events[0].event == "update")
        #expect(events[0].retry == 5000)
        #expect(events[0].data == "test data")
    }
    
    @Test("Decode multiline data")
    func testMultilineData() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        data: first line
        data: second line
        data: third line
        
        """
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].data == "first line\nsecond line\nthird line")
    }
    
    @Test("Decode multiple events")
    func testMultipleEvents() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        data: first
        
        data: second
        
        data: third
        
        """
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 3)
        #expect(events[0].data == "first")
        #expect(events[1].data == "second")
        #expect(events[2].data == "third")
    }
    
    @Test("Ignore comment lines")
    func testCommentLines() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        : this is a comment
        data: hello
        : another comment
        
        """
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].data == "hello")
    }
    
    @Test("Handle field without colon")
    func testFieldWithoutColon() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        data
        
        """
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].data == "")
    }
    
    @Test("Strip leading space after colon")
    func testStripLeadingSpace() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        data: with space
        data:without space
        
        """
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].data == "with space\nwithout space")
    }
    
    @Test("BOM stripping at stream start")
    func testBOMStripping() {
        let decoder = DefaultSSEEventDecoder()
        let bom = "\u{FEFF}"
        let input = bom + "data: hello\n\n"
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].data == "hello")
    }
    
    @Test("BOM only stripped once")
    func testBOMStrippedOnce() {
        let decoder = DefaultSSEEventDecoder()
        let bom = "\u{FEFF}"
        
        let first = Data((bom + "data: first\n\n").utf8)
        let events1 = decoder.decode(first)
        #expect(events1.count == 1)
        #expect(events1[0].data == "first")
        
        let second = Data((bom + "data: second\n\n").utf8)
        let events2 = decoder.decode(second)
        #expect(events2.count == 1)
        #expect(events2[0].data == bom + "second")
    }
    
    @Test("Chunked decoding")
    func testChunkedDecoding() {
        let decoder = DefaultSSEEventDecoder()
        
        let chunk1 = Data("data: hel".utf8)
        let events1 = decoder.decode(chunk1)
        #expect(events1.isEmpty)
        
        let chunk2 = Data("lo\n\n".utf8)
        let events2 = decoder.decode(chunk2)
        #expect(events2.count == 1)
        #expect(events2[0].data == "hello")
    }
    
    @Test("Empty event ignored")
    func testEmptyEventIgnored() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        
        
        data: valid
        
        """
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].data == "valid")
    }
    
    @Test("Invalid retry value")
    func testInvalidRetry() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        retry: not-a-number
        data: test
        
        """
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].retry == nil)
    }
    
    @Test("Unknown fields ignored")
    func testUnknownFields() {
        let decoder = DefaultSSEEventDecoder()
        let input = """
        unknown: field
        data: test
        custom: value
        
        """
        let data = Data(input.utf8)
        
        let events = decoder.decode(data)
        
        #expect(events.count == 1)
        #expect(events[0].data == "test")
    }
}

@Suite("TypedSSEEvent Tests")
struct TypedSSEEventTests {
    @Test("TypedSSEEvent initialization")
    func testTypedEventInit() {
        struct User: Codable, Sendable {
            let name: String
        }
        
        let event = TypedSSEEvent(
            id: "1",
            event: "user.created",
            payload: User(name: "Alice")
        )
        
        #expect(event.id == "1")
        #expect(event.event == "user.created")
        #expect(event.payload.name == "Alice")
    }
}
