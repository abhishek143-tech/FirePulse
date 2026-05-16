import Foundation
import Testing
@testable import FirePulse

@Suite(.serialized)
struct FirePulseTests {
@Test func firePulseConfigurationStoresValues() {
    let configuration = FirePulseConfiguration(
        identityPoolId: "identity-pool",
        region: "us-east-1",
        firehoseStreamName: "stream-name"
    )

    #expect(configuration.identityPoolId == "identity-pool")
    #expect(configuration.region == "us-east-1")
    #expect(configuration.firehoseStreamName == "stream-name")
}

@Test func sigV4SignerAppliesExpectedHeaders() throws {
    let fixedDate = Date(timeIntervalSince1970: 0)
    let signer = SigV4RequestSigner(region: "us-east-1", dateProvider: { fixedDate })
    let credentials = AWSCredentials(
        accessKeyId: "access-key",
        secretAccessKey: "secret-key",
        sessionToken: "session-token"
    )
    let payload = Data("{}".utf8)
    var request = URLRequest(url: URL(string: "https://firehose.us-east-1.amazonaws.com/")!)
    request.httpMethod = Constants.AWS.postMethod

    let signedRequest = try signer.sign(request, payload: payload, credentials: credentials)
    let authorization = try #require(signedRequest.value(forHTTPHeaderField: Constants.Headers.authorization))

    #expect(signedRequest.httpBody == payload)
    #expect(signedRequest.value(forHTTPHeaderField: Constants.Headers.amzDate) == "19700101T000000Z")
    #expect(signedRequest.value(forHTTPHeaderField: Constants.Headers.amzSecurityToken) == "session-token")
    #expect(signedRequest.value(forHTTPHeaderField: Constants.Headers.amzTarget) == Constants.Firehose.putRecordTarget)
    #expect(signedRequest.value(forHTTPHeaderField: Constants.Headers.contentType) == Constants.AWS.jsonContentType)
    #expect(authorization.contains("Credential=access-key/19700101/us-east-1/firehose/aws4_request"))
    #expect(authorization.contains("SignedHeaders=host;x-amz-date;x-amz-security-token"))
    #expect(authorization.contains("Signature="))
}

@Test func cognitoCredentialsProviderReturnsCredentials() async throws {
    nonisolated(unsafe) var requestCount = 0
    MockURLProtocol.requestHandler = { request in
        requestCount += 1

        if requestCount == 1 {
            return try MockURLProtocol.jsonResponse([Constants.Cognito.identityId: "identity-id"], for: request)
        }

        return try MockURLProtocol.jsonResponse([
            Constants.Cognito.credentials: [
                Constants.Cognito.accessKeyId: "access-key",
                Constants.Cognito.secretKey: "secret-key",
                Constants.Cognito.sessionToken: "session-token"
            ]
        ], for: request)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let provider = CognitoCredentialsProvider(
        identityPoolId: "identity-pool",
        region: "us-east-1",
        urlSession: .firePulseMockSession()
    )

    let credentials = try await provider.credentials()

    #expect(credentials.accessKeyId == "access-key")
    #expect(credentials.secretAccessKey == "secret-key")
    #expect(credentials.sessionToken == "session-token")
    #expect(requestCount == 2)
}

@Test func awsFirehoseClientSendsBase64EncodedRecordPayload() async throws {
    MockURLProtocol.requestHandler = { request in
        #expect(request.url?.absoluteString == "https://firehose.us-east-1.amazonaws.com/")
        #expect(request.httpMethod == Constants.AWS.postMethod)
        #expect(request.value(forHTTPHeaderField: "X-Test-Signed") == "true")

        let body = try request.firePulseBodyData()
        let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let record = try #require(payload[Constants.Firehose.record] as? [String: Any])
        let base64Data = try #require(record[Constants.Firehose.data] as? String)
        let eventData = try #require(Data(base64Encoded: base64Data))
        let eventJSON = try #require(JSONSerialization.jsonObject(with: eventData) as? [String: Any])

        #expect(payload[Constants.Firehose.deliveryStreamName] as? String == "stream-name")
        #expect(eventJSON["name"] as? String == "demo")
        #expect(eventJSON["count"] as? Int == 2)

        return try MockURLProtocol.jsonResponse(["ok": true], for: request)
    }
    defer { MockURLProtocol.requestHandler = nil }

    let client = AWSFirehoseClient(
        configuration: FirePulseConfiguration(
            identityPoolId: "identity-pool",
            region: "us-east-1",
            firehoseStreamName: "stream-name"
        ),
        credentialsProvider: MockCredentialsProvider(),
        requestSigner: MockRequestSigner(),
        urlSession: .firePulseMockSession()
    )

    try await client.putRecord(TestAnalyticsEvent(name: "demo", count: 2))
}
}

private struct TestAnalyticsEvent: Encodable, Sendable {
    let name: String
    let count: Int
}

private struct MockCredentialsProvider: AWSCredentialsProvider {
    func credentials() async throws -> AWSCredentials {
        AWSCredentials(
            accessKeyId: "access-key",
            secretAccessKey: "secret-key",
            sessionToken: "session-token"
        )
    }
}

private struct MockRequestSigner: AWSRequestSigner {
    func sign(_ request: URLRequest, payload: Data, credentials: AWSCredentials) throws -> URLRequest {
        var signedRequest = request
        signedRequest.httpBody = payload
        signedRequest.setValue("true", forHTTPHeaderField: "X-Test-Signed")
        return signedRequest
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = try #require(Self.requestHandler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func jsonResponse(_ object: [String: Any], for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url,
              let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [Constants.Headers.contentType: "application/json"]
        ) else {
            throw FirePulseError.invalidResponse
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        return (response, data)
    }
}

private extension URLSession {
    static func firePulseMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
private extension URLRequest {
    func firePulseBodyData() throws -> Data {
        if let httpBody {
            return httpBody
        }

        guard let httpBodyStream else {
            throw FirePulseError.invalidPayload
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while httpBodyStream.hasBytesAvailable {
            let bytesRead = httpBodyStream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                throw FirePulseError.invalidPayload
            }
            if bytesRead == 0 {
                break
            }
            data.append(buffer, count: bytesRead)
        }

        return data
    }
}
