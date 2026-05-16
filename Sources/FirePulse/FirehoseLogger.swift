//
//  FirehoseLogger.swift
//  FirePulse
//
//  Created by Abhishek Dilip Dhok on 16/05/26.
//

final class FirehoseLogger: @unchecked Sendable {
    private let client: any FirehoseClient

    /// Creates a logger backed by a Firehose client.
    ///
    /// - Parameter client: Client that sends encoded events to Firehose.
    init(client: any FirehoseClient) {
        self.client = client
    }

    /// Logs an analytics event and prints a success or failure message.
    ///
    /// - Parameter event: Event payload to send.
    func logEvent<T: Encodable & Sendable>(_ event: T) async {
        do {
            try await client.putRecord(event)
            print(Constants.LogMessages.eventSuccess)
        } catch {
            print(Constants.LogMessages.eventFailure)
        }
    }
}
