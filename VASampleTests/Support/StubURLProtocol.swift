//
//  StubURLProtocol.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation

final class StubURLProtocol: URLProtocol {
    struct Stub {
        let status: Int
        var body: String = ""
        var headers: [String: String] = [:]
    }

    nonisolated(unsafe) static var stubs: [Stub] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []

    static func reset(_ stubs: [Stub]) {
        self.stubs = stubs
        requests = []
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func body(of request: URLRequest) -> [String: Any]? {
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        guard !Self.stubs.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let stub = Self.stubs.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.status, httpVersion: nil, headerFields: stub.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
