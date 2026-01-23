//
//  EventStream.swift
//  SwiftSSE
//
//  Created by squidypal on 2026-01-20.
//

import Vapor
import Foundation
import SwiftSSECore

public struct EventStream: AsyncResponseEncodable {
    private let stream: @Sendable (EventStreamWriter) async throws -> Void
    private let jsonEncoder: JSONEncoder
    
    public init(
        encoder: JSONEncoder = JSONEncoder(),
        stream: @escaping @Sendable (EventStreamWriter) async throws -> Void
    ) {
        self.jsonEncoder = encoder
        self.stream = stream
    }
    
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        response.headers.contentType = .init(type: "text", subType: "event-stream")
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
        response.headers.replaceOrAdd(name: .connection, value: "keep-alive")
        
        let (asyncStream, continuation) = AsyncStream<ByteBuffer>.makeStream()
        let writer = EventStreamWriter(continuation: continuation, jsonEncoder: jsonEncoder)
        let streamHandler = stream
        
        Task.detached {
            do {
                try await streamHandler(writer)
            } catch {
                request.logger.error("EventStream error: \(error)")
            }
            await writer.close()
        }
        
        response.body = .init(managedAsyncStream: { bodyWriter in
            for await chunk in asyncStream {
                try await bodyWriter.write(.buffer(chunk))
            }
        })
        
        return response
    }
}
