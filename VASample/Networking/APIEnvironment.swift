//
//  APIEnvironment.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated enum APIEnvironment {
    static let baseURL = URL(string: "http://localhost:8080")!
    static let timeout: TimeInterval = 20
}
