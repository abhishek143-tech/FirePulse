//
//  Constants.swift
//  FirePulse
//
//  Created by Abhishek Dilip Dhok on 15/05/26.
//

struct Constants {
    static let identityPoolID = "identityPoolId"
    static let region = "region"
    static let firehoseStreamName = "firehoseStreamName"

    struct AWS {
        static let cognitoIdentityURLTemplate = "https://cognito-identity.%@.amazonaws.com/"
        static let firehoseURLTemplate = "https://firehose.%@.amazonaws.com%@"
        static let jsonContentType = "application/x-amz-json-1.1"
        static let postMethod = "POST"
        static let firehoseServiceName = "firehose"
        static let signatureAlgorithm = "AWS4-HMAC-SHA256"
        static let signatureKeyPrefix = "AWS4"
        static let aws4Request = "aws4_request"
        static let canonicalURI = "/"
        static let authorizationHeaderFormat = "AWS4-HMAC-SHA256 Credential=%@/%@, SignedHeaders=%@, Signature=%@"
        static let credentialScopeFormat = "%@/%@/firehose/aws4_request"
    }

    struct Headers {
        static let contentType = "Content-Type"
        static let amzTarget = "X-Amz-Target"
        static let amzDate = "x-amz-date"
        static let amzSecurityToken = "x-amz-security-token"
        static let authorization = "Authorization"
        static let signedHeaders = "host;x-amz-date;x-amz-security-token"
        static let canonicalHeadersFormat = "host:%@\nx-amz-date:%@\nx-amz-security-token:%@\n"
    }

    struct Cognito {
        static let getIdTarget = "AWSCognitoIdentityService.GetId"
        static let getCredentialsForIdentityTarget = "AWSCognitoIdentityService.GetCredentialsForIdentity"
        static let identityPoolId = "IdentityPoolId"
        static let identityId = "IdentityId"
        static let credentials = "Credentials"
        static let accessKeyId = "AccessKeyId"
        static let secretKey = "SecretKey"
        static let sessionToken = "SessionToken"
        static let expiration = "Expiration"
    }

    struct Firehose {
        static let putRecordTarget = "Firehose_20150804.PutRecord"
        static let deliveryStreamName = "DeliveryStreamName"
        static let record = "Record"
        static let data = "Data"
        static let successMessagePrefix = "Data successfully sent to Firehose: "
    }

    struct DateFormats {
        static let amzDate = "yyyyMMdd'T'HHmmss'Z'"
        static let dateStamp = "yyyyMMdd"
        static let utcDate = "yyyy-MM-dd"
        static let utcIdentifier = "UTC"
    }

    struct Formatting {
        static let twoDigitHex = "%02x"
        static let twoDigitHmacHex = "%02hhx"
    }

    struct Signature {
        static let canonicalRequestFormat = "%@\n%@\n\n%@\n%@\n%@"
        static let stringToSignFormat = "%@\n%@\n%@\n%@"
    }

    struct Errors {
        static let domain = ""
        static let code = 0
    }

    struct LogMessages {
        static let loginEventSuccess = "Login event sent to Firehose successfully."
        static let loginEventFailure = "Failed to send login event to Firehose."
        static let eventSuccess = "FirePulse event sent to Firehose successfully."
        static let eventFailure = "FirePulse failed to send event to Firehose."
        static let awsCredentialsFailurePrefix = "Failed to fetch AWS credentials: "
    }
}
