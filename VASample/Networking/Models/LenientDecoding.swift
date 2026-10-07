//
//  LenientDecoding.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/07.
//

import Foundation

/// A string enum that decodes values it doesn't know as `unknown` instead of failing the whole response.
nonisolated protocol UnknownCaseDecodable: RawRepresentable, Decodable where RawValue == String {
    static var unknown: Self { get }
}

nonisolated extension UnknownCaseDecodable {
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

/// Decodes an element, or `nil` if it's malformed, so one bad element doesn't fail the whole array.
nonisolated struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
