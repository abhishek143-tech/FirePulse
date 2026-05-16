//
//  AWSCredentialsProvider.swift
//  FirePulse
//
//  Created by Abhishek Dilip Dhok on 16/05/26.
//

import Foundation

protocol AWSCredentialsProvider: Sendable {
    /// Fetches temporary AWS credentials for signing Firehose requests.
    ///
    /// - Returns: Temporary AWS credentials.
    /// - Throws: `FirePulseError` or a networking error when credentials cannot be fetched.
    func credentials() async throws -> AWSCredentials
}

protocol AWSRequestSigner: Sendable {
    /// Signs a URL request using the supplied payload and AWS credentials.
    ///
    /// - Parameters:
    ///   - request: Unsigned request to sign.
    ///   - payload: Request body bytes included in the signature hash.
    ///   - credentials: Temporary AWS credentials used to derive the signing key.
    /// - Returns: A request with AWS SigV4 headers applied.
    /// - Throws: `FirePulseError.invalidURL` or `FirePulseError.invalidPayload`.
    func sign(_ request: URLRequest, payload: Data, credentials: AWSCredentials) throws -> URLRequest
}

protocol FirehoseClient: Sendable {
    /// Sends one encodable analytics event to Firehose.
    ///
    /// - Parameter event: Event payload to encode and send.
    /// - Throws: Encoding, signing, credential, or networking errors.
    func putRecord<T: Encodable & Sendable>(_ event: T) async throws
}
