//
//  SigV4RequestSigner.swift
//  FirePulse
//
//  Created by Abhishek Dilip Dhok on 16/05/26.
//

import Foundation
import CommonCrypto

struct SigV4RequestSigner: AWSRequestSigner {
    private let region: String
    private let dateProvider: @Sendable () -> Date

    /// Creates a SigV4 signer for Firehose requests.
    ///
    /// - Parameters:
    ///   - region: AWS region included in the credential scope.
    ///   - dateProvider: Clock used to produce signing timestamps.
    init(region: String, dateProvider: @escaping @Sendable () -> Date = Date.init) {
        self.region = region
        self.dateProvider = dateProvider
    }

    /// Applies AWS Signature Version 4 headers to a request.
    ///
    /// - Parameters:
    ///   - request: Unsigned request.
    ///   - payload: Request body bytes included in the canonical request hash.
    ///   - credentials: Temporary AWS credentials.
    /// - Returns: Signed request ready to send to AWS Firehose.
    /// - Throws: `FirePulseError.invalidURL` or `FirePulseError.invalidPayload`.
    func sign(_ request: URLRequest, payload: Data, credentials: AWSCredentials) throws -> URLRequest {
        guard let url = request.url, let host = url.host else {
            throw FirePulseError.invalidURL
        }

        var signedRequest = request
        signedRequest.httpBody = payload

        let now = dateProvider()
        let amzDate = formattedDate(now, format: Constants.DateFormats.amzDate)
        let dateStamp = formattedDate(now, format: Constants.DateFormats.dateStamp)
        let canonicalHeaders = String(
            format: Constants.Headers.canonicalHeadersFormat,
            host,
            amzDate,
            credentials.sessionToken
        )
        let signedHeaders = Constants.Headers.signedHeaders
        let payloadHash = bytesToHex(hash(payload))
        let canonicalURI = url.path.isEmpty ? Constants.AWS.canonicalURI : url.path

        let canonicalRequest = String(
            format: Constants.Signature.canonicalRequestFormat,
            signedRequest.httpMethod ?? Constants.AWS.postMethod,
            canonicalURI,
            canonicalHeaders,
            signedHeaders,
            payloadHash
        )
        let credentialScope = String(format: Constants.AWS.credentialScopeFormat, dateStamp, region)
        guard let canonicalRequestData = canonicalRequest.data(using: .utf8) else {
            throw FirePulseError.invalidPayload
        }

        let stringToSign = String(
            format: Constants.Signature.stringToSignFormat,
            Constants.AWS.signatureAlgorithm,
            amzDate,
            credentialScope,
            bytesToHex(hash(canonicalRequestData))
        )
        let signingKey = signatureKey(
            credentials.secretAccessKey,
            dateStamp,
            region,
            Constants.AWS.firehoseServiceName
        )
        let signature = hmacSHA256Hex(data: stringToSign, key: signingKey)
        let authorizationHeader = String(
            format: Constants.AWS.authorizationHeaderFormat,
            credentials.accessKeyId,
            credentialScope,
            signedHeaders,
            signature
        )

        signedRequest.setValue(Constants.Firehose.putRecordTarget, forHTTPHeaderField: Constants.Headers.amzTarget)
        signedRequest.setValue(amzDate, forHTTPHeaderField: Constants.Headers.amzDate)
        signedRequest.setValue(credentials.sessionToken, forHTTPHeaderField: Constants.Headers.amzSecurityToken)
        signedRequest.setValue(authorizationHeader, forHTTPHeaderField: Constants.Headers.authorization)
        signedRequest.setValue(Constants.AWS.jsonContentType, forHTTPHeaderField: Constants.Headers.contentType)

        return signedRequest
    }

    /// Formats a date in UTC for AWS signing.
    ///
    /// - Parameters:
    ///   - date: Date to format.
    ///   - format: Date format string expected by SigV4.
    /// - Returns: UTC-formatted date string.
    private func formattedDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(identifier: Constants.DateFormats.utcIdentifier)
        return formatter.string(from: date)
    }

    /// Calculates an HMAC-SHA256 digest and returns it as lowercase hex.
    ///
    /// - Parameters:
    ///   - data: String to sign.
    ///   - key: HMAC key.
    /// - Returns: Hex-encoded HMAC digest.
    private func hmacSHA256Hex(data: String, key: Data) -> String {
        let cData = data.cString(using: .utf8)
        var result = [CUnsignedChar](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), (key as NSData).bytes, key.count, cData, Int(strlen(cData!)), &result)
        return result.map { String(format: Constants.Formatting.twoDigitHmacHex, $0) }.joined()
    }

    /// Derives the AWS SigV4 signing key for a date, region, and service.
    ///
    /// - Parameters:
    ///   - key: AWS secret access key.
    ///   - dateStamp: Signing date in `yyyyMMdd` format.
    ///   - regionName: AWS region.
    ///   - serviceName: AWS service name, such as `firehose`.
    /// - Returns: Derived signing key.
    private func signatureKey(_ key: String, _ dateStamp: String, _ regionName: String, _ serviceName: String) -> Data {
        let kDate = hmacSHA256((Constants.AWS.signatureKeyPrefix + key).data(using: .utf8)!, dateStamp)
        let kRegion = hmacSHA256(kDate, regionName)
        let kService = hmacSHA256(kRegion, serviceName)
        return hmacSHA256(kService, Constants.AWS.aws4Request)
    }

    /// Calculates an HMAC-SHA256 digest.
    ///
    /// - Parameters:
    ///   - key: HMAC key.
    ///   - data: String to sign.
    /// - Returns: Raw digest bytes.
    private func hmacSHA256(_ key: Data, _ data: String) -> Data {
        var result = [CUnsignedChar](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), (key as NSData).bytes, key.count, data, data.count, &result)
        return Data(result)
    }

    /// Converts bytes to a lowercase hexadecimal string.
    ///
    /// - Parameter bytes: Data to encode.
    /// - Returns: Hex string.
    private func bytesToHex(_ bytes: Data) -> String {
        bytes.map { String(format: Constants.Formatting.twoDigitHex, $0) }.joined()
    }

    /// Calculates a SHA-256 hash.
    ///
    /// - Parameter data: Data to hash.
    /// - Returns: Raw SHA-256 digest bytes.
    private func hash(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
}
