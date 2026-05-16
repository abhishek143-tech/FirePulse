import Foundation
import FirePulse

/// Structure of an Event,
///  Edit this according to your need.
struct DemoAnalyticsEvent: Encodable, Sendable {
    let eventName: String
    let userId: String
    let screenName: String
    let timestamp: String
}

/// Demonstrates how a consuming app can configure FirePulse and send one analytics event.
///
/// Replace the placeholder AWS values with a real Cognito identity pool ID, AWS region,
/// and Firehose delivery stream name before running this against AWS.
func runFirePulseDemo() async {
    let configuration = FirePulseConfiguration(
        identityPoolId: "us-east-1:your-identity-pool-id",
        region: "us-east-1",
        firehoseStreamName: "your-firehose-stream-name"
    )

    let firePulse = FirePulse(configuration: configuration)
    let event = DemoAnalyticsEvent(
        eventName: "demo_event",
        userId: "demo-user-id",
        screenName: "Home",
        timestamp: ISO8601DateFormatter().string(from: Date())
    )

    await firePulse.log(event)
}
