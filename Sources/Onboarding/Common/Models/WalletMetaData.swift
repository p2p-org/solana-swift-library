// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Foundation

public struct WalletMetaData: Codable, Equatable {
    public let deviceName: String
    public let email: String
    public let authProvider: String
    public let phoneNumber: String

    enum CodingKeys: String, CodingKey {
        case deviceName = "device_name"
        case email
        case authProvider = "auth_provider"
        case phoneNumber = "phone_number"
    }

    /// Encrypt metadata using seed phrase
    ///
    /// - Parameter seedPhrase:
    /// - Returns: Base64 encrypted metadata
    /// - Throws:
    public func encrypt(seedPhrase: String) throws -> String {
        let metaDataJson = try JSONEncoder().encode(self)
        let encryptedMetadataRaw = try Crypto.encryptMetadata(seedPhrase: seedPhrase, data: metaDataJson)
        return String(data: try JSONEncoder().encode(encryptedMetadataRaw), encoding: .utf8)!
    }

    /// Decrypt metadata using seed phrase
    public static func decrypt(seedPhrase: String, data: String) throws -> Self {
        let encryptedMetadata = try JSONDecoder()
            .decode(Crypto.EncryptedMetadata.self, from: Data(bytes: data.utf8))
        let metadataRaw = try Crypto.decryptMetadata(
            seedPhrase: seedPhrase,
            encryptedMetadata: encryptedMetadata
        )
        return try JSONDecoder().decode(WalletMetaData.self, from: metadataRaw)
    }
}