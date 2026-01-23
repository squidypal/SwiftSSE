//
//  EventStreamWriter.swift
//  SwiftSSE
//
//  Created by squidypal on 2026-01-19.
//

import Vapor
import Foundation
import SwiftSSECore

public actor EventStreamWriter {
    private let continuation: AsyncStream<ByteBuffer>.Continuation
    private let sseEncoder: SSEEventEncoder
    private let jsonEncoder: JSONEncoder
    private var isClosed = false

    init(
        continuation: AsyncStream<ByteBuffer>.Continuation,
        sseEncoder: SSEEventEncoder = DefaultSSEEventEncoder(),
        jsonEncoder: JSONEncoder = JSONEncoder()
    ) {
        self.continuation = continuation
        self.sseEncoder = sseEncoder
        self.jsonEncoder = jsonEncoder
    }
    
    public func send(_ event: SSEEvent) throws {
        guard !isClosed else {
            throw Abort(.internalServerError, reason: "Stream is closed")
        }
        
        let data = sseEncoder.encode(event)
        continuation.yield(ByteBuffer(data: data))
    }
    
    public func send<T: Encodable>(event: String? = nil, payload: T, encoder: JSONEncoder? = nil) throws {
        let encoder = encoder ?? jsonEncoder
        let jsonData = try encoder.encode(payload)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        try send(SSEEvent(event: event, data: jsonString))
    }
    
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        continuation.finish()
    }
}
