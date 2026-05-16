//
//  AWSFirehoseClient.swift
//  FirePulse
//
//  Created by Abhishek Dilip Dhok on 16/05/26.
//

import Foundation

final class AWSFirehoseClient: FirehoseClient, @unchecked Sendable {
    private let configuration: FirePulseConfiguration
    private let credentialsProvider: any AWSCredentialsProvider
    private let requestSigner: any AWSRequestSigner
    private let urlSession: URLSession

    /// Creates a Firehose client with injectable dependencies.
    ///
    /// - Parameters:
    ///   - configuration: FirePulse AWS configuration.
    ///   - credentialsProvider: Provider used to fetch temporary AWS credentials.
    ///   - requestSigner: Signer used to add SigV4 authorization headers.
    ///   - urlSession: Session used for Firehose network requests.
    init(
        configuration: FirePulseConfiguration,
        credentialsProvider: any AWSCredentialsProvider,
        requestSigner: any AWSRequestSigner,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.credentialsProvider = credentialsProvider
        self.requestSigner = requestSigner
        self.urlSession = urlSession
    }

    /// Encodes and sends one event to the configured Firehose delivery stream.
    ///
    /// - Parameter event: Event payload to JSON-encode and send.
    /// - Throws: Credential, encoding, signing, URL, or networking errors.
    func putRecord<T: Encodable & Sendable>(_ event: T) async throws {
        let credentials = try await credentialsProvider.credentials()
        let payload = try makePayload(for: event)
        let request = try makeRequest(payload: payload, credentials: credentials)
        let (_, _) = try await urlSession.firePulseData(for: request)
    }

    /// Builds the Firehose `PutRecord` request payload for an event.
    ///
    /// - Parameter event: Event payload to JSON-encode and base64-wrap for Firehose.
    /// - Returns: Serialized Firehose request body.
    /// - Throws: JSON encoding or serialization errors.
    private func makePayload<T: Encodable>(for event: T) throws -> Data {
        let jsonData = try JSONEncoder().encode(event)
        let base64EncodedData = jsonData.base64EncodedString()
        let payload: [String: Any] = [
            Constants.Firehose.deliveryStreamName: configuration.firehoseStreamName,
            Constants.Firehose.record: [Constants.Firehose.data: base64EncodedData]
        ]

        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// Creates and signs the Firehose `PutRecord` request.
    ///
    /// - Parameters:
    ///   - payload: Serialized Firehose request body.
    ///   - credentials: Temporary AWS credentials used for SigV4 signing.
    /// - Returns: Signed Firehose request.
    /// - Throws: URL construction or signing errors.
    private func makeRequest(payload: Data, credentials: AWSCredentials) throws -> URLRequest {
        let endpoint = String(
            format: Constants.AWS.firehoseURLTemplate,
            configuration.region,
            Constants.AWS.canonicalURI
        )
        guard let url = URL(string: endpoint) else {
            throw FirePulseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = Constants.AWS.postMethod
        return try requestSigner.sign(request, payload: payload, credentials: credentials)
    }
}
