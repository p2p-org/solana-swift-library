// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Foundation
import SolanaSwift

public struct Recipient: Hashable {
    public struct Attribute: OptionSet, Hashable {
        public let rawValue: Int

        public static let funds = Attribute(rawValue: 1 << 0)
        public static let pda = Attribute(rawValue: 1 << 1)
    
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public enum Category: Hashable {
        case username(name: String, domain: String)

        case solanaAddress
        case solanaTokenAddress(walletAddress: PublicKey, token: Token)

        case bitcoinAddress
    }

    public init(address: String, category: Category, attributes: Attribute) {
        self.address = address
        self.category = category
        self.attributes = attributes
    }

    public let address: String
    public let category: Category

    public let attributes: Attribute
}

extension Recipient: Identifiable {
    public var id: String { "\(address)-\(attributes)-\(category)" }
}