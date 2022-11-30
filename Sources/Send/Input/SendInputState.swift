// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import FeeRelayerSwift
import Foundation
import SolanaSwift

public enum Amount: Equatable {
    case fiat(value: Double, currency: String)
    case token(lamport: UInt64, mint: String, decimals: Int)
}

public enum SendInputAction: Equatable {
    case initialize(FeeRelayerContext)

    case update

    case changeAmountInFiat(Double)
    case changeAmountInToken(Double)
    case changeUserToken(Token)
    case changeFeeToken(Token)
    case send
}

public struct SendInputServices {
    let swapService: SwapService
    let feeService: SendFeeCalculator
    let solanaAPIClient: SolanaAPIClient

    public init(swapService: SwapService, feeService: SendFeeCalculator, solanaAPIClient: SolanaAPIClient) {
        self.swapService = swapService
        self.feeService = feeService
        self.solanaAPIClient = solanaAPIClient
    }
}

public struct SendInputState: Equatable {
    public enum ErrorReason: Equatable {
        case networkConnectionError(NSError)

        case inputTooHigh
        case inputTooLow(Double)
        case inputZero

        case feeCalculationFailed

        case requiredInitialize
        case missingFeeRelayer
        case initializeFailed(NSError)

        case unknown(NSError)
    }

    public enum Status: Equatable {
        case requiredInitialize
        case ready
        case error(reason: ErrorReason)
    }

    public struct RecipientAdditionalInfo: Equatable {
        ///  Usable when recipient category is ``Recipient.Category.solanaAddress``
        public let splAccounts: [SolanaSwift.TokenAccount<AccountInfo>]

        public init(splAccounts: [SolanaSwift.TokenAccount<AccountInfo>]) { self.splAccounts = splAccounts }

        public static let zero: RecipientAdditionalInfo = .init(splAccounts: [])
    }

    public let status: Status

    let recipient: Recipient
    let recipientAdditionalInfo: RecipientAdditionalInfo
    let token: Token
    let userWalletEnvironments: UserWalletEnvironments

    let amountInFiat: Double
    let amountInToken: Double

    public let fee: FeeAmount
    public let tokenFee: Token
    public let feeInToken: FeeAmount
    public let feeRelayerContext: FeeRelayerContext?

    public init(
        status: Status,
        recipient: Recipient,
        recipientAdditionalInfo: RecipientAdditionalInfo,
        token: Token,
        userWalletEnvironments: UserWalletEnvironments,
        amountInFiat: Double,
        amountInToken: Double,
        fee: FeeAmount,
        tokenFee: Token,
        feeInToken: FeeAmount,
        feeRelayerContext: FeeRelayerContext?
    ) {
        self.status = status
        self.recipient = recipient
        self.recipientAdditionalInfo = recipientAdditionalInfo
        self.token = token
        self.userWalletEnvironments = userWalletEnvironments
        self.amountInFiat = amountInFiat
        self.amountInToken = amountInToken
        self.fee = fee
        self.tokenFee = tokenFee
        self.feeInToken = feeInToken
        self.feeRelayerContext = feeRelayerContext
    }

    public static func zero(
        status: Status = .requiredInitialize,
        recipient: Recipient,
        recipientAdditionalInfo: RecipientAdditionalInfo = .zero,
        token: Token,
        feeToken: Token,
        userWalletState: UserWalletEnvironments,
        feeRelayerContext: FeeRelayerContext? = nil
    ) -> SendInputState {
        .init(
            status: status,
            recipient: recipient,
            recipientAdditionalInfo: recipientAdditionalInfo,
            token: token,
            userWalletEnvironments: userWalletState,
            amountInFiat: 0,
            amountInToken: 0,
            fee: .zero,
            tokenFee: feeToken,
            feeInToken: .zero,
            feeRelayerContext: feeRelayerContext
        )
    }

    func copy(
        status: Status? = nil,
        recipient: Recipient? = nil,
        recipientAdditionalInfo: RecipientAdditionalInfo? = nil,
        token: Token? = nil,
        userWalletEnvironments: UserWalletEnvironments? = nil,
        amountInFiat: Double? = nil,
        amountInToken: Double? = nil,
        fee: FeeAmount? = nil,
        tokenFee: Token? = nil,
        feeInToken: FeeAmount? = nil,
        feeRelayerContext: FeeRelayerContext? = nil
    ) -> SendInputState {
        .init(
            status: status ?? self.status,
            recipient: recipient ?? self.recipient,
            recipientAdditionalInfo: recipientAdditionalInfo ?? self.recipientAdditionalInfo,
            token: token ?? self.token,
            userWalletEnvironments: userWalletEnvironments ?? self.userWalletEnvironments,
            amountInFiat: amountInFiat ?? self.amountInFiat,
            amountInToken: amountInToken ?? self.amountInToken,
            fee: fee ?? self.fee,
            tokenFee: tokenFee ?? self.tokenFee,
            feeInToken: feeInToken ?? self.feeInToken,
            feeRelayerContext: feeRelayerContext ?? self.feeRelayerContext
        )
    }
}

public extension SendInputState {
    var maxAmountInputInToken: Double {
        var balance: Lamports = userWalletEnvironments.wallets.first(where: { $0.token.address == token.address })?
            .lamports ?? 0

        if token.address == tokenFee.address {
            balance = balance - feeInToken.total
        }

        return Double(balance) / pow(10, Double(token.decimals))
    }

    var maxAmountInputInFiat: Double {
        maxAmountInputInToken * (userWalletEnvironments.exchangeRate[token.symbol]?.value ?? 0)
    }
}
