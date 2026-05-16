//
//  URLSession+FirePulse.swift
//  FirePulse
//
//  Created by Abhishek Dilip Dhok on 16/05/26.
//

import Foundation

extension URLSession {
    /// Runs a data task with async/await support for FirePulse networking.
    ///
    /// - Parameter request: URL request to execute.
    /// - Returns: Response data and URL response.
    /// - Throws: A networking error or `FirePulseError.invalidResponse` when data/response is missing.
    func firePulseData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let response else {
                    continuation.resume(throwing: FirePulseError.invalidResponse)
                    return
                }

                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}
