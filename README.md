# FirePulse

FirePulse is a lightweight Swift library for sending analytics events from Apple apps directly to an Amazon Kinesis Data Firehose delivery stream.

The library uses Amazon Cognito Identity to request temporary AWS credentials, signs Firehose requests with AWS Signature Version 4, JSON-encodes your Swift event models, and sends them with Firehose `PutRecord`.

## Features

- Swift Package Manager support
- Async/await API
- Works with any `Encodable & Sendable` event payload
- Uses temporary Cognito Identity credentials instead of hard-coded AWS keys
- Signs Firehose requests with SigV4
- Supports iOS, macOS, tvOS, and watchOS targets

## Requirements

- Swift 5.7 or later
- iOS 13.0+
- macOS 10.15+
- tvOS 13.0+
- watchOS 6.0+
- An AWS Cognito Identity Pool
- An Amazon Kinesis Data Firehose delivery stream

## Installation

Add FirePulse to your app with Swift Package Manager.

In Xcode:

1. Open your app project.
2. Select **File > Add Package Dependencies**.
3. Enter the FirePulse repository URL.
4. Add the `FirePulse` library product to your app target.

Or add it to another Swift package:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/your-org/FirePulse.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourAppTarget",
        dependencies: ["FirePulse"]
    )
]
```

Replace the package URL and version with the values for your repository.

## AWS Setup

FirePulse needs three AWS values:

- `identityPoolId`: Cognito Identity Pool ID, for example `us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- `region`: AWS region for both Cognito Identity and Firehose, for example `us-east-1`
- `firehoseStreamName`: Firehose delivery stream name that should receive events

The unauthenticated or authenticated IAM role attached to your Cognito Identity Pool must be allowed to call `firehose:PutRecord` on your Firehose delivery stream.

Example IAM policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "firehose:PutRecord",
      "Resource": "arn:aws:firehose:us-east-1:123456789012:deliverystream/your-firehose-stream-name"
    }
  ]
}
```

Update the region, account ID, and stream name for your AWS account.

## Quick Start

Create a configuration and a `FirePulse` instance:

```swift
import FirePulse

let firePulse = FirePulse(
    configuration: FirePulseConfiguration(
        identityPoolId: "us-east-1:your-identity-pool-id",
        region: "us-east-1",
        firehoseStreamName: "your-firehose-stream-name"
    )
)
```

Define any event type that conforms to `Encodable` and `Sendable`:

```swift
struct AnalyticsEvent: Encodable, Sendable {
    let eventName: String
    let userId: String
    let screenName: String
    let timestamp: String
}
```

Send the event from an async context:

```swift
let event = AnalyticsEvent(
    eventName: "screen_view",
    userId: "user-123",
    screenName: "Home",
    timestamp: ISO8601DateFormatter().string(from: Date())
)

await firePulse.log(event)
```

## Working SwiftUI Example

```swift
import SwiftUI
import FirePulse

struct AnalyticsEvent: Encodable, Sendable {
    let eventName: String
    let userId: String
    let screenName: String
    let timestamp: String
}

@main
struct DemoApp: App {
    private let firePulse = FirePulse(
        configuration: FirePulseConfiguration(
            identityPoolId: "us-east-1:your-identity-pool-id",
            region: "us-east-1",
            firehoseStreamName: "your-firehose-stream-name"
        )
    )

    var body: some Scene {
        WindowGroup {
            ContentView(firePulse: firePulse)
        }
    }
}

struct ContentView: View {
    let firePulse: FirePulse

    var body: some View {
        VStack(spacing: 16) {
            Text("FirePulse Demo")
                .font(.title)

            Button("Send Event") {
                Task {
                    await sendEvent()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func sendEvent() async {
        let event = AnalyticsEvent(
            eventName: "button_tap",
            userId: "demo-user-id",
            screenName: "Home",
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        await firePulse.log(event)
    }
}
```

Before running the example, replace the placeholder Cognito Identity Pool ID, AWS region, and Firehose stream name with real AWS values.

## How It Works

1. `FirePulseConfiguration` stores your Cognito Identity Pool ID, AWS region, and Firehose stream name.
2. `FirePulse.log(_:)` accepts any `Encodable & Sendable` event.
3. FirePulse requests an identity ID from Cognito Identity.
4. FirePulse exchanges that identity ID for temporary AWS credentials.
5. The event is JSON-encoded and base64-wrapped for Firehose `PutRecord`.
6. The Firehose request is signed with AWS Signature Version 4.
7. The signed request is sent to the configured delivery stream.

## Public API

### `FirePulseConfiguration`

```swift
public struct FirePulseConfiguration: Sendable {
    public let identityPoolId: String
    public let region: String
    public let firehoseStreamName: String

    public init(
        identityPoolId: String,
        region: String,
        firehoseStreamName: String
    )
}
```

### `FirePulse`

```swift
public final class FirePulse: @unchecked Sendable {
    public init(configuration: FirePulseConfiguration)

    public func log<T: Encodable & Sendable>(_ event: T) async
}
```

## Notes

- `log(_:)` is asynchronous and should be called with `await`.
- Events must be JSON-encodable.
- FirePulse currently sends one event per `PutRecord` request.
- The current API prints success or failure messages instead of throwing errors to the caller.
- Do not store long-lived AWS access keys in your app. Use Cognito Identity Pool roles with the minimum permissions your app needs.

## Troubleshooting

If events are not appearing in Firehose:

- Confirm that the Cognito Identity Pool ID is correct.
- Confirm that the region matches both Cognito Identity and Firehose.
- Confirm that the Firehose delivery stream name is correct.
- Confirm that the Cognito IAM role allows `firehose:PutRecord` for the stream ARN.
- Check the Xcode console for FirePulse success or failure messages.
- Check AWS CloudWatch logs and Firehose delivery stream monitoring for rejected or failed records.

## Example File

A smaller standalone example is available in `Examples/FirePulseDemo.swift`.
