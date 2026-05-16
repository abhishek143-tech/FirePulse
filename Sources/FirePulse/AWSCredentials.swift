//
//  AWSCredentials.swift
//  FirePulse
//
//  Created by Abhishek Dilip Dhok on 16/05/26.
//

import Foundation

struct AWSCredentials: Sendable {
    let accessKeyId: String
    let secretAccessKey: String
    let sessionToken: String
}
