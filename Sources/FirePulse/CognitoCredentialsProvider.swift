//
//  CognitoCredentialsProvider.swift
//  FirePulse
//
//  Created by Abhishek Dilip Dhok on 16/05/26.
//

import Foundation

struct CognitoCredentialsProvider: AWSCredentialsProvider {
    private let identityPoolId: String
    private let region: String
    private let urlSession: URLSession

    /// Creates a Cognito credentials provider.
    ///
    /// - Parameters:
    ///   - identityPoolId: Cognito identity pool ID used by `GetId`.
    ///   - region: AWS region for Cognito Identity.
    ///   - urlSession: Session used for Cognito network requests.
    init(identityPoolId: String, region: String, urlSession: URLSession = .shared) {
        self.identityPoolId = identityPoolId
        self.region = region
        self.urlSession = urlSession
    }

    /// Fetches temporary AWS credentials from Cognito Identity.
    ///
    /// - Returns: Temporary credentials containing access key, secret key, and session token.
    /// - Throws: A networking, serialization, or `FirePulseError` failure.
    func credentials() async throws -> AWSCredentials {
        let identityId = try await fetchIdentityId()
        return try await fetchCredentials(for: identityId)
    }

    /// Requests a Cognito identity ID for the configured identity pool.
    ///
    /// - Returns: Cognito identity ID.
    /// - Throws: `FirePulseError.invalidResponse` when Cognito does not return an identity ID.
    private func fetchIdentityId() async throws -> String {
        let response = try await performCognitoRequest(
            target: Constants.Cognito.getIdTarget,
            body: [Constants.Cognito.identityPoolId: identityPoolId]
        )

        guard let identityId = response[Constants.Cognito.identityId] as? String else {
            throw FirePulseError.invalidResponse
        }

        return identityId
    }

    /// Exchanges a Cognito identity ID for temporary AWS credentials.
    ///
    /// - Parameter identityId: Cognito identity ID returned by `fetchIdentityId()`.
    /// - Returns: Temporary AWS credentials.
    /// - Throws: `FirePulseError.missingCredentials` when required credential fields are absent.
    private func fetchCredentials(for identityId: String) async throws -> AWSCredentials {
        let response = try await performCognitoRequest(
            target: Constants.Cognito.getCredentialsForIdentityTarget,
            body: [Constants.Cognito.identityId: identityId]
        )

        guard let credentials = response[Constants.Cognito.credentials] as? [String: Any],
              let accessKeyId = credentials[Constants.Cognito.accessKeyId] as? String,
              let secretAccessKey = credentials[Constants.Cognito.secretKey] as? String,
              let sessionToken = credentials[Constants.Cognito.sessionToken] as? String else {
            throw FirePulseError.missingCredentials
        }

        return AWSCredentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken
        )
    }

    /// Performs a Cognito Identity JSON request and returns the decoded object.
    ///
    /// - Parameters:
    ///   - target: AWS `X-Amz-Target` operation name.
    ///   - body: JSON request body.
    /// - Returns: Response object decoded as a dictionary.
    /// - Throws: URL, networking, JSON serialization, or response-shape errors.
    private func performCognitoRequest(target: String, body: [String: Any]) async throws -> [String: Any] {
        let cognitoIdentityURL = String(format: Constants.AWS.cognitoIdentityURLTemplate, region)
        guard let url = URL(string: cognitoIdentityURL) else {
            throw FirePulseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = Constants.AWS.postMethod
        request.setValue(Constants.AWS.jsonContentType, forHTTPHeaderField: Constants.Headers.contentType)
        request.setValue(target, forHTTPHeaderField: Constants.Headers.amzTarget)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await urlSession.firePulseData(for: request)
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FirePulseError.invalidResponse
        }

        return response
    }
}
