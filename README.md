# SwiftSSE

A Swift package for Server-Sent Events (SSE) with dual mode support: server side streaming for Vapor and client-side consumption for iOS/macOS/Linux.

## Features

- Shared types across server and client
- Native async/await API using Swift Concurrency
- Full SSE specification compliance
- Automatic reconnection with configurable strategies
- Linux compatible for Vapor deployments

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/squidypal/SwiftSSE.git", from: "1.0.0")
]
```

## Usage

### Server (Vapor)

```swift
import SwiftSSEServer

app.get("events") { req -> EventStream in
    EventStream { writer in
        for i in 1...10 {
            try await writer.send(SSEEvent(data: "Event \(i)"))
            try await Task.sleep(for: .seconds(1))
        }
    }
}
```

### Client

```swift
import SwiftSSEClient

let client = SSEClient(url: URL(string: "https://api.example.com/events")!)

for try await event in client.events {
    print(event.data)
}
```

## Modules

| Module | Purpose |
|--------|---------|
| SwiftSSECore | Shared types and event parsing |
| SwiftSSEServer | Vapor middleware & response streaming |
| SwiftSSEClient | URLSession (Apple) / AsyncHTTPClient (Linux) consumer |

## Platform Support

- **SwiftSSECore**: Linux, macOS, iOS
- **SwiftSSEServer**: Linux, macOS
- **SwiftSSEClient**: Linux, macOS, iOS

## Requirements

- Swift 6.0+
- macOS 12+ / iOS 15+
- Vapor 4+ (server module)

## License

MIT
