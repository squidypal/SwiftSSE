//
//  SSEEvent.swift
//  SwiftSSE
//
//  Created by squidypal on 2026-01-19.
//

import Foundation

public struct SSEEvent: Sendable {
    public var id: String?
    public var event: String?
    public var data: String
    public var retry: Int?
    
    public init(id: String? = nil, event: String? = nil, data: String, retry: Int? = nil) {
        self.id = id
        self.event = event
        self.data = data
        self.retry = retry
    }
    
    public func decode<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
          let data = Data(self.data.utf8)
          return try decoder.decode(type, from: data)
    }
}

public struct TypedSSEEvent<T: Decodable>: Sendable where T: Sendable {
    public let id: String?
    public let event: String?
    public let payload: T
    
    public init(id: String?, event: String?, payload: T) {
        self.id = id
        self.event = event
        self.payload = payload
    }
}
