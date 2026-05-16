//
//  FirePulseConfiguration.swift
//  FirePulse
//
//  Created by Abhishek Dilip Dhok on 16/05/26.
//

public struct FirePulseConfiguration: Sendable {
    public let identityPoolId: String
    public let region: String
    public let firehoseStreamName: String

    /// Creates the AWS configuration required by FirePulse.
    ///
    /// - Parameters:
    ///   - identityPoolId: Cognito identity pool ID used to request temporary AWS credentials.
    ///   - region: AWS region that hosts Cognito and Firehose, such as `us-east-1`.
    ///   - firehoseStreamName: Firehose delivery stream that receives analytics events.
    public init(identityPoolId: String, region: String, firehoseStreamName: String) {
        self.identityPoolId = identityPoolId
        self.region = region
        self.firehoseStreamName = firehoseStreamName
    }
}

public final class FirePulse: @unchecked Sendable {
    private let logger: FirehoseLogger

    /// Creates a FirePulse logger using the supplied AWS configuration.
    ///
    /// - Parameter configuration: AWS Cognito and Firehose configuration for this logger.
    public init(configuration: FirePulseConfiguration) {
        let credentialsProvider = CognitoCredentialsProvider(
            identityPoolId: configuration.identityPoolId,
            region: configuration.region
        )
        let requestSigner = SigV4RequestSigner(region: configuration.region)
        let client = AWSFirehoseClient(
            configuration: configuration,
            credentialsProvider: credentialsProvider,
            requestSigner: requestSigner
        )

        self.logger = FirehoseLogger(client: client)
    }

    /// Sends an encodable analytics event to the configured Firehose stream.
    ///
    /// - Parameter event: Event payload to JSON-encode and send.
    public func log<T: Encodable & Sendable>(_ event: T) async {
        await logger.logEvent(event)
    }
}
