//
//  EventStream.swift
//  SwiftSSE
//
//  Created by squidypal on 2026-01-20.
//

import Foundation
import Vapor
import SwiftSSECore

public struct EventStream: AsyncResponseEncodable {
    private let stream: (EventStreamWriter) async throws -> Void
    private let jsonEncoder: JSONEncoder
    
    public init(
        encoder: JSONEncoder = JSONEncoder(),
        stream: @escaping (EventStreamWriter) async throws -> Void
    ) {
        self.jsonEncoder = encoder
        self.stream = stream
    }
    
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        response.headers.contentType = .init(type: "Text", subType: "event-stream")
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
    }
}
