//
//  AnalyticsManager .swift
//  p2p_wallet
//
//  Created by Chung Tran on 11/06/2021.
//

import Foundation

public protocol AnalyticsManager {
    func log(event: AnalyticsEvent)
}

public class AnalyticsManagerImpl: AnalyticsManager {
    private let providers: [AnalyticsProvider]
    
    public init(providers: [AnalyticsProvider]) {
        self.providers = providers
    }

    public func log(event: AnalyticsEvent) {
        providers.forEach { provider in
            // exclude sending to specific providers
            guard !event.excludedProviderIds.contains(where: {$0.rawValue == provider.providerId.rawValue})
            else { return }
            
            // log event to provider
            provider.logEvent(event)
        }
    }
}
