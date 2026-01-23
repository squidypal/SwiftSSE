//
//  SSEClient.swift
//  SwiftSSE
//
//  Created by squidypal on 2026-01-22.
//

import Foundation
import SwiftSSECore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if os(Linux)
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
#endif

public enum ReconnectStrategy: Sendable {
    case never
    case immediate
    case exponentialBackoff(base: TimeInterval, max: TimeInterval)
}

public actor SSEClient {
    private let url: URL
    private let headers: [String: String]
    private let reconnectStrategy: ReconnectStrategy
    private let decoder: JSONDecoder
    
    private var lastEventId: String?
    private var serverRetryInterval: TimeInterval?
    private var currentTask: Task<Void, Never>?
    
    #if os(Linux)
    private var httpClient: HTTPClient?
    #endif
    
    public init(
        url: URL,
        headers: [String: String] = [:],
        reconnectStrategy: ReconnectStrategy = .exponentialBackoff(base: 1.0, max: 30.0),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.url = url
        self.headers = headers
        self.reconnectStrategy = reconnectStrategy
        self.decoder = decoder
    }
    
    deinit {
        #if os(Linux)
        try? httpClient?.syncShutdown()
        #endif
    }
    
    public var events: SSEEventStream {
        SSEEventStream(client: self)
    }
    
    public func events<T: Decodable>(
        of eventType: String,
        decoder: JSONDecoder? = nil
    ) -> TypedSSEEventStream<T> {
        TypedSSEEventStream(client: self, eventType: eventType, decoder: decoder ?? self.decoder)
    }
    
    internal nonisolated func connect() -> AsyncStream<SSEEvent> {
        AsyncStream { continuation in
            let task = Task {
                var attemptCount = 0
                
                while !Task.isCancelled {
                    do {
                        try await streamEvents(continuation: continuation)
                        
                        guard shouldReconnect() else {
                            break
                        }
                        
                        let retry = await getServerRetryInterval()
                        let delay = calculateDelay(attempt: attemptCount, serverRetry: retry)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        attemptCount += 1
                        
                    } catch is CancellationError {
                        break
                    } catch {
                        guard shouldReconnect() else {
                            break
                        }
                        
                        let retry = await getServerRetryInterval()
                        let delay = calculateDelay(attempt: attemptCount, serverRetry: retry)
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        attemptCount += 1
                    }
                }
                
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    private func streamEvents(continuation: AsyncStream<SSEEvent>.Continuation) async throws {
        #if os(Linux)
        try await streamEventsLinux(continuation: continuation)
        #else
        try await streamEventsApple(continuation: continuation)
        #endif
    }
    
    #if !os(Linux)
    private func streamEventsApple(continuation: AsyncStream<SSEEvent>.Continuation) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let lastEventId = lastEventId {
            request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
        }
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let eventDecoder = DefaultSSEEventDecoder()
        var buffer = Data()
        
        for try await byte in bytes {
            buffer.append(byte)
            
            if buffer.count >= 1024 {
                let events = eventDecoder.decode(buffer)
                buffer.removeAll(keepingCapacity: true)
                
                for event in events {
                    if let id = event.id {
                        await updateLastEventId(id)
                    }
                    
                    if let retry = event.retry {
                        await updateRetryInterval(TimeInterval(retry) / 1000.0)
                    }
                    
                    continuation.yield(event)
                }
            }
        }
        
        if !buffer.isEmpty {
            let events = eventDecoder.decode(buffer)
            for event in events {
                if let id = event.id {
                    await updateLastEventId(id)
                }
                continuation.yield(event)
            }
        }
    }
    #endif
    
    #if os(Linux)
    private func streamEventsLinux(continuation: AsyncStream<SSEEvent>.Continuation) async throws {
        if httpClient == nil {
            httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        }
        
        guard let client = httpClient else {
            struct ClientNotInitializedError: Error {}
            throw ClientNotInitializedError()
        }
        
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .GET
        request.headers.add(name: "Accept", value: "text/event-stream")
        
        for (key, value) in headers {
            request.headers.add(name: key, value: value)
        }
        
        if let lastEventId = lastEventId {
            request.headers.add(name: "Last-Event-ID", value: lastEventId)
        }
        
        let response = try await client.execute(request, timeout: .none)
        
        guard (200...299).contains(response.status.code) else {
            struct BadResponseError: Error {}
            throw BadResponseError()
        }
        
        let eventDecoder = DefaultSSEEventDecoder()
        
        for try await chunk in response.body {
            let data = Data(chunk.readableBytesView)
            let events = eventDecoder.decode(data)
            
            for event in events {
                if let id = event.id {
                    await updateLastEventId(id)
                }
                
                if let retry = event.retry {
                    await updateRetryInterval(TimeInterval(retry) / 1000.0)
                }
                
                continuation.yield(event)
            }
        }
    }
    #endif
    
    private func updateLastEventId(_ id: String) async {
        lastEventId = id
    }
    
    private func updateRetryInterval(_ interval: TimeInterval) async {
        serverRetryInterval = interval
    }
    
    private func getServerRetryInterval() async -> TimeInterval? {
        serverRetryInterval
    }
    
    private nonisolated func shouldReconnect() -> Bool {
        switch reconnectStrategy {
        case .never:
            return false
        case .immediate, .exponentialBackoff:
            return true
        }
    }
    
    private nonisolated func calculateDelay(attempt: Int, serverRetry: TimeInterval?) -> TimeInterval {
        if let serverRetry = serverRetry {
            return serverRetry
        }
        
        switch reconnectStrategy {
        case .never:
            return 0
        case .immediate:
            return 0
        case .exponentialBackoff(let base, let max):
            let delay = base * pow(2.0, Double(attempt))
            return min(delay, max)
        }
    }
}

public struct SSEEventStream: AsyncSequence {
    public typealias Element = SSEEvent
    
    private let client: SSEClient
    
    init(client: SSEClient) {
        self.client = client
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: client.connect())
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncStream<SSEEvent>.Iterator
        
        init(stream: AsyncStream<SSEEvent>) {
            self.iterator = stream.makeAsyncIterator()
        }
        
        public mutating func next() async throws -> SSEEvent? {
            await iterator.next()
        }
    }
}

public struct TypedSSEEventStream<T: Decodable>: AsyncSequence where T: Sendable {
    public typealias Element = T
    
    private let client: SSEClient
    private let eventType: String
    private let decoder: JSONDecoder
    
    init(client: SSEClient, eventType: String, decoder: JSONDecoder) {
        self.client = client
        self.eventType = eventType
        self.decoder = decoder
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            stream: client.connect(),
            eventType: eventType,
            decoder: decoder
        )
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncStream<SSEEvent>.Iterator
        private let eventType: String
        private let decoder: JSONDecoder
        
        init(stream: AsyncStream<SSEEvent>, eventType: String, decoder: JSONDecoder) {
            self.iterator = stream.makeAsyncIterator()
            self.eventType = eventType
            self.decoder = decoder
        }
        
        public mutating func next() async throws -> T? {
            while let event = await iterator.next() {
                if event.event == eventType {
                    return try event.decode(T.self, decoder: decoder)
                }
            }
            return nil
        }
    }
}
